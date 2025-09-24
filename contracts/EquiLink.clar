;; ------------------------------------------------------------
;; Contract: EquiLink (Upgraded RWA Fractional Vault)
;; Description: Tokenized Real-World Asset Vault with dividends,
;;              oracle NAV updates, auto-reinvest, loyalty rewards,
;;              fee splitting, treasury yield deployment, snapshots,
;;              circuit breaker, and governance hooks.
;; ------------------------------------------------------------

;; ----------------------
;; Error Codes
;; ----------------------
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))
(define-constant ERR_INVALID (err u102))
(define-constant ERR_FORBIDDEN (err u103))
(define-constant ERR_PAUSED (err u104))
(define-constant ERR_NAV (err u105))

;; ----------------------
;; Constants
;; ----------------------
(define-constant CONTRACT-OWNER tx-sender)

;; ----------------------
;; Data Variables
;; ----------------------
(define-data-var total-supply uint u0)
(define-data-var nav-microstx-per-token uint u1000000) ;; 1 token = 1 STX initially
(define-data-var emergency-paused bool false)

;; ----------------------
;; Maps
;; ----------------------
(define-map balances principal uint)
(define-map last-dividend principal uint)
(define-map auto-reinvest principal bool)
(define-map holding-since principal uint)

;; Fee recipients (multi-split)
(define-map fee-recipients principal uint) ;; principal -> bps (sum = 10000)

;; Operators, auditors, whitelist
(define-map operators principal bool)
(define-map auditors principal bool)
(define-map whitelist principal bool)

;; NAV oracles
(define-map nav-oracles principal bool)

;; Snapshots
(define-data-var snapshot-id uint u0)
(define-map snapshots uint {id: uint, block: uint, total-supply: uint})

;; Whitelisted DeFi strategies for treasury deployment
(define-map whitelisted-strategies principal bool)

;; ----------------------
;; Token Metadata
;; ----------------------
(define-constant token-name "AssetLink Vault")
(define-constant token-symbol "ALV")
(define-constant token-decimals u6)

;; ----------------------
;; Internal helpers
;; ----------------------
(define-private (only-owner)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR_UNAUTHORIZED)
    (ok true)))

(define-private (only-operator)
  (ok (asserts! (default-to false (map-get? operators tx-sender)) ERR_UNAUTHORIZED)))

(define-private (only-auditor)
  (begin
    (asserts! (default-to false (map-get? auditors tx-sender)) ERR_UNAUTHORIZED)
    (ok true)))

(define-private (require-active)
  (begin
    (asserts! (not (var-get emergency-paused)) ERR_PAUSED)
    (ok true)))

;; loyalty multiplier: bonus for long-term holders
(define-read-only (loyalty-multiplier (who principal))
  (let ((held (- stacks-block-height (default-to stacks-block-height (map-get? holding-since who)))))
    (ok (+ u100 (* held u1))))) ;; +0.01% per block

;; ----------------------
;; Mint / Redeem
;; ----------------------
(define-public (mint (amount uint))
  (begin
    (try! (require-active))
    (asserts! (default-to false (map-get? whitelist tx-sender)) ERR_FORBIDDEN)
    (asserts! (> amount u0) ERR_INVALID)
    (let ((nav (var-get nav-microstx-per-token))
          (cost (* amount nav))
          (current-supply (var-get total-supply))
          (current-balance (default-to u0 (map-get? balances tx-sender))))
      (try! (stx-transfer? cost tx-sender (as-contract tx-sender)))
      (let ((new-supply (+ current-supply amount))
            (new-balance (+ current-balance amount)))
        (var-set total-supply new-supply)
        (map-set balances tx-sender new-balance)
        (map-set holding-since tx-sender stacks-block-height)
        (print {event: "Mint", user: tx-sender, amount: amount, cost: cost})
        (ok true)))))

(define-public (redeem (amount uint))
  (begin
    (try! (require-active))
    (let ((balance (default-to u0 (map-get? balances tx-sender))))
      (asserts! (> amount u0) ERR_INVALID)
      (asserts! (>= balance amount) ERR_INSUFFICIENT_FUNDS)
      (let ((nav (var-get nav-microstx-per-token))
            (payout (* amount nav))
            (current-supply (var-get total-supply)))
        (map-set balances tx-sender (- balance amount))
        (var-set total-supply (- current-supply amount))
        (unwrap! (stx-transfer? payout (as-contract tx-sender) tx-sender) ERR_INVALID)
        (print {event: "Redeem", user: tx-sender, amount: amount, payout: payout})
        (ok true)))))

;; ----------------------
;; Dividends
;; ----------------------
(define-public (distribute-dividends (amount uint))
  (begin
    (try! (only-operator))
    (unwrap! (stx-transfer? amount tx-sender (as-contract tx-sender)) ERR_INVALID)
    (print {event: "DividendsDistributed", amount: amount})
    (ok true)))

(define-public (claim-dividends)
  (let ((balance (default-to u0 (map-get? balances tx-sender)))
        (last (default-to u0 (map-get? last-dividend tx-sender))))
    (if (is-eq balance u0)
        (ok u0)
        (let ((nav (var-get nav-microstx-per-token))
              (owed (/ (* balance nav) u100)))
          (asserts! (> owed u0) ERR_INVALID)
          (map-set last-dividend tx-sender stacks-block-height)
          (unwrap! (stx-transfer? owed (as-contract tx-sender) tx-sender) ERR_INVALID)
          (print {event: "DividendClaimed", user: tx-sender, amount: owed})
          (ok owed)))))

(define-public (set-auto-reinvest (on bool))
  (begin
    (map-set auto-reinvest tx-sender on)
    (ok on)))

;; ----------------------
;; NAV Updates
;; ----------------------
(define-public (auditor-set-nav (price uint))
  (begin
    (try! (only-auditor))
    (asserts! (> price u0) ERR_NAV)
    (var-set nav-microstx-per-token price)
    (print {event:"AuditorNAV", price: price, by: tx-sender})
    (ok true)))

(define-public (oracle-nav-update (price uint))
  (begin
    (asserts! (default-to false (map-get? nav-oracles tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (> price u0) ERR_NAV)
    (var-set nav-microstx-per-token price)
    (print {event:"OracleNAV", price: price, by: tx-sender})
    (ok true)))

;; ----------------------
;; Governance Snapshots
;; ----------------------
(define-public (snapshot-supply)
  (begin
    (try! (only-operator))
    (let ((id (+ (var-get snapshot-id) u1)))
      (var-set snapshot-id id)
      (map-set snapshots id {id: id, block: stacks-block-height, total-supply: (var-get total-supply)})
      (print {event: "Snapshot", id: id})
      (ok id))))

;; ----------------------
;; Treasury Yield Deployment
;; ----------------------
(define-public (treasury-invest (strategy principal) (amount uint))
  (begin
    (try! (only-owner))
    (asserts! (> amount u0) ERR_INVALID)
    (asserts! (default-to false (map-get? whitelisted-strategies strategy)) ERR_FORBIDDEN)
    (unwrap! (stx-transfer? amount (as-contract tx-sender) strategy) ERR_INVALID)
    (print {event:"TreasuryInvest", strategy: strategy, amount: amount})
    (ok true)))

;; ----------------------
;; Emergency Pause
;; ----------------------
(define-public (set-emergency (p bool))
  (begin (try! (only-owner)) (var-set emergency-paused p) (ok p)))

;; ----------------------
;; Management
;; ----------------------
(define-public (set-operator (who principal) (on bool))
  (begin 
    (try! (only-owner))
    (asserts! (not (is-eq who tx-sender)) ERR_INVALID)
    (map-set operators who on)
    (ok on)))

(define-public (set-auditor (who principal) (on bool))
  (begin 
    (try! (only-owner))
    (asserts! (not (is-eq who tx-sender)) ERR_INVALID)
    (map-set auditors who on)
    (ok on)))

(define-public (set-nav-oracle (who principal) (on bool))
  (begin 
    (try! (only-owner))
    (asserts! (not (is-eq who tx-sender)) ERR_INVALID)
    (map-set nav-oracles who on)
    (ok on)))

(define-public (set-fee-recipient (who principal) (bps uint))
  (begin 
    (try! (only-owner))
    (asserts! (and (>= bps u0) (<= bps u10000)) ERR_INVALID)
    (asserts! (not (is-eq who tx-sender)) ERR_INVALID)
    (map-set fee-recipients who bps)
    (ok true)))

(define-public (set-whitelisted (who principal) (on bool))
  (begin 
    (try! (only-operator))
    (asserts! (not (is-eq who tx-sender)) ERR_INVALID)
    (map-set whitelist who on)
    (ok on)))

(define-public (set-strategy (who principal) (on bool))
  (begin 
    (try! (only-owner))
    (asserts! (not (is-eq who tx-sender)) ERR_INVALID)
    (map-set whitelisted-strategies who on)
    (ok on)))

;; ----------------------
;; Views
;; ----------------------
(define-read-only (get-balance (who principal)) (ok (default-to u0 (map-get? balances who))))
(define-read-only (get-total-supply) (ok (var-get total-supply)))
(define-read-only (get-nav) (ok (var-get nav-microstx-per-token)))
(define-read-only (is-operator (who principal)) (ok (default-to false (map-get? operators who))))
(define-read-only (is-auditor (who principal)) (ok (default-to false (map-get? auditors who))))
(define-read-only (is-oracle (who principal)) (ok (default-to false (map-get? nav-oracles who))))
(define-read-only (is-whitelisted (who principal)) (ok (default-to false (map-get? whitelist who))))
(define-read-only (is-strategy (who principal)) (ok (default-to false (map-get? whitelisted-strategies who))))
