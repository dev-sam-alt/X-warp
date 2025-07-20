;; X-Warp Contract
;; A DAO for decentralized space exploration governance and cosmic decision-making

;; Constants for configuration
(define-constant ERR-UNAUTHORIZED-EXPLORER (err u200))
(define-constant ERR-EXPLORER-ALREADY-REGISTERED (err u201))
(define-constant ERR-EXPLORER-NOT-FOUND (err u202))
(define-constant ERR-MISSION-NOT-FOUND (err u203))
(define-constant ERR-ALREADY-PARTICIPATED (err u204))
(define-constant ERR-MISSION-EXPIRED (err u205))
(define-constant ERR-ALREADY-LAUNCHED (err u206))
(define-constant ERR-INSUFFICIENT-CONSENSUS (err u207))
(define-constant ERR-MISSION-FAILED (err u208))
(define-constant ERR-INVALID-MISSION-NAME (err u209))
(define-constant ERR-INVALID-BRIEFING (err u210))
(define-constant ERR-CONSENSUS-NOT-REACHED (err u211))
(define-constant ERR-SUPERNOVA-THRESHOLD-NOT-MET (err u212))
(define-constant ERR-CANNOT-DELEGATE-TO-SELF (err u213))
(define-constant ERR-INVALID-NAVIGATOR (err u214))

;; Cosmic governance parameters
(define-constant ORBIT_PERIOD u144) ;; ~24 hours in stellar blocks
(define-constant MIN_MISSION_NAME_LENGTH u4)
(define-constant MAX_MISSION_NAME_LENGTH u50)
(define-constant MIN_BRIEFING_LENGTH u10)
(define-constant MAX_BRIEFING_LENGTH u500)
(define-constant STELLAR_CONSENSUS_PERCENTAGE u30) ;; 30% of explorers must participate
(define-constant SUPERNOVA_PERCENTAGE u67) ;; 67% approval needed for critical missions

;; Mission types
(define-constant MISSION-TYPE-STANDARD u1)
(define-constant MISSION-TYPE-CRITICAL u2) ;; Requires supernova consensus

;; Data maps for storing cosmic state
(define-map space-explorers principal bool)
(define-data-var explorer-count uint u0)

;; Navigation delegation system
(define-map navigation-delegations principal principal)

(define-map cosmic-missions
    uint
    {
        mission-commander: principal,
        mission-name: (string-ascii 50),
        mission-briefing: (string-utf8 500),
        mission-type: uint,
        approval-count: uint,
        rejection-count: uint,
        launch-block: uint,
        mission-launched: bool
    }
)

(define-map mission-participation {mission-id: uint, explorer: principal} bool)

;; Data variables
(define-data-var mission-count uint u0)
(define-data-var nexus-commander principal tx-sender)

;; Read-only functions
(define-read-only (is-space-explorer (explorer principal))
    (default-to false (map-get? space-explorers explorer))
)

(define-read-only (get-cosmic-mission (mission-id uint))
    (map-get? cosmic-missions mission-id)
)

(define-read-only (has-participated (mission-id uint) (explorer principal))
    (default-to false (map-get? mission-participation {mission-id: mission-id, explorer: explorer}))
)

(define-read-only (get-total-explorers)
    (var-get explorer-count)
)

;; Navigation delegation read functions
(define-read-only (get-navigator (explorer principal))
    (map-get? navigation-delegations explorer)
)

;; Private helper functions
(define-private (is-valid-mission-name (mission-name (string-ascii 50)))
    (let
        ((length (len mission-name)))
        (and
            (>= length MIN_MISSION_NAME_LENGTH)
            (<= length MAX_MISSION_NAME_LENGTH)
            (not (is-eq mission-name ""))
        )
    )
)

(define-private (is-valid-briefing (briefing (string-utf8 500)))
    (let
        ((length (len briefing)))
        (and
            (>= length MIN_BRIEFING_LENGTH)
            (<= length MAX_BRIEFING_LENGTH)
            (not (is-eq briefing u""))
        )
    )
)

(define-private (calculate-consensus-percentage (approvals uint) (total-participation uint))
    (if (is-eq total-participation u0)
        u0
        (/ (* approvals u100) total-participation)
    )
)

(define-private (has-reached-stellar-consensus (total-participation uint))
    (let
        ((required-participation (/ (* (var-get explorer-count) STELLAR_CONSENSUS_PERCENTAGE) u100)))
        (>= total-participation required-participation)
    )
)

(define-private (has-reached-supernova-threshold (approvals uint) (total-participation uint))
    (>= (calculate-consensus-percentage approvals total-participation) SUPERNOVA_PERCENTAGE)
)

;; Public functions
(define-public (register-explorer (new-explorer principal))
    (begin
        (asserts! (is-eq tx-sender (var-get nexus-commander)) ERR-UNAUTHORIZED-EXPLORER)
        (asserts! (not (is-space-explorer new-explorer)) ERR-EXPLORER-ALREADY-REGISTERED)
        (var-set explorer-count (+ (var-get explorer-count) u1))
        (ok (map-set space-explorers new-explorer true))
    )
)

(define-public (remove-explorer (explorer principal))
    (begin
        (asserts! (is-eq tx-sender (var-get nexus-commander)) ERR-UNAUTHORIZED-EXPLORER)
        (asserts! (is-space-explorer explorer) ERR-EXPLORER-NOT-FOUND)
        (var-set explorer-count (- (var-get explorer-count) u1))
        (map-delete navigation-delegations explorer)
        (ok (map-delete space-explorers explorer))
    )
)

;; Navigation delegation system
(define-public (delegate-navigation (navigator principal))
    (begin
        (asserts! (is-space-explorer tx-sender) ERR-UNAUTHORIZED-EXPLORER)
        (asserts! (is-space-explorer navigator) ERR-EXPLORER-NOT-FOUND)
        (asserts! (not (is-eq tx-sender navigator)) ERR-CANNOT-DELEGATE-TO-SELF)
        (ok (map-set navigation-delegations tx-sender navigator))
    )
)

;; Remove navigation delegation
(define-public (revoke-navigation-delegation)
    (begin
        (asserts! (is-space-explorer tx-sender) ERR-UNAUTHORIZED-EXPLORER)
        (ok (map-delete navigation-delegations tx-sender))
    )
)

(define-public (propose-mission 
    (mission-name (string-ascii 50)) 
    (mission-briefing (string-utf8 500))
    (mission-type uint)
)
    (let
        ((mission-id (var-get mission-count)))
        (begin
            (asserts! (is-space-explorer tx-sender) ERR-UNAUTHORIZED-EXPLORER)
            (asserts! (is-valid-mission-name mission-name) ERR-INVALID-MISSION-NAME)
            (asserts! (is-valid-briefing mission-briefing) ERR-INVALID-BRIEFING)
            (asserts! (or (is-eq mission-type MISSION-TYPE-STANDARD)
                         (is-eq mission-type MISSION-TYPE-CRITICAL)) ERR-UNAUTHORIZED-EXPLORER)
            
            (map-set cosmic-missions mission-id
                {
                    mission-commander: tx-sender,
                    mission-name: mission-name,
                    mission-briefing: mission-briefing,
                    mission-type: mission-type,
                    approval-count: u0,
                    rejection-count: u0,
                    launch-block: block-height,
                    mission-launched: false
                }
            )
            (var-set mission-count (+ mission-id u1))
            (ok mission-id)
        )
    )
)

(define-public (participate-in-mission (mission-id uint) (approve bool))
    (let
        ((mission (unwrap! (get-cosmic-mission mission-id) ERR-MISSION-NOT-FOUND))
         (navigator-check (get-navigator tx-sender)))
        (begin
            (asserts! (is-space-explorer tx-sender) ERR-UNAUTHORIZED-EXPLORER)
            ;; Check if the explorer hasn't delegated their navigation
            (asserts! (is-none navigator-check) ERR-UNAUTHORIZED-EXPLORER)
            (asserts! (not (has-participated mission-id tx-sender)) ERR-ALREADY-PARTICIPATED)
            (asserts! (< (- block-height (get launch-block mission)) ORBIT_PERIOD) ERR-MISSION-EXPIRED)
            
            (map-set mission-participation {mission-id: mission-id, explorer: tx-sender} true)
            
            (if approve
                (map-set cosmic-missions mission-id 
                    (merge mission {approval-count: (+ (get approval-count mission) u1)}))
                (map-set cosmic-missions mission-id 
                    (merge mission {rejection-count: (+ (get rejection-count mission) u1)}))
            )
            (ok true)
        )
    )
)

;; Navigator participation function
(define-public (navigate-for-explorer (delegator principal) (mission-id uint) (approve bool))
    (let
        ((mission (unwrap! (get-cosmic-mission mission-id) ERR-MISSION-NOT-FOUND))
         (navigator-check (get-navigator delegator)))
        (begin
            (asserts! (is-space-explorer tx-sender) ERR-UNAUTHORIZED-EXPLORER)
            (asserts! (is-space-explorer delegator) ERR-EXPLORER-NOT-FOUND)
            ;; Check if the delegator has delegated to the sender
            (asserts! (and (is-some navigator-check) 
                          (is-eq (some tx-sender) navigator-check)) 
                     ERR-UNAUTHORIZED-EXPLORER)
            (asserts! (not (has-participated mission-id delegator)) ERR-ALREADY-PARTICIPATED)
            (asserts! (< (- block-height (get launch-block mission)) ORBIT_PERIOD) ERR-MISSION-EXPIRED)
            
            (map-set mission-participation {mission-id: mission-id, explorer: delegator} true)
            
            (if approve
                (map-set cosmic-missions mission-id 
                    (merge mission {approval-count: (+ (get approval-count mission) u1)}))
                (map-set cosmic-missions mission-id 
                    (merge mission {rejection-count: (+ (get rejection-count mission) u1)}))
            )
            (ok true)
        )
    )
)

(define-public (launch-mission (mission-id uint))
    (let
        (
            (mission (unwrap! (get-cosmic-mission mission-id) ERR-MISSION-NOT-FOUND))
            (total-participation (+ (get approval-count mission) (get rejection-count mission)))
        )
        (begin
            (asserts! (is-space-explorer tx-sender) ERR-UNAUTHORIZED-EXPLORER)
            (asserts! (>= (- block-height (get launch-block mission)) ORBIT_PERIOD) ERR-MISSION-EXPIRED)
            (asserts! (not (get mission-launched mission)) ERR-ALREADY-LAUNCHED)
            (asserts! (has-reached-stellar-consensus total-participation) ERR-CONSENSUS-NOT-REACHED)
            
            ;; Check if supernova threshold is required
            (if (is-eq (get mission-type mission) MISSION-TYPE-CRITICAL)
                (asserts! (has-reached-supernova-threshold (get approval-count mission) total-participation)
                         ERR-SUPERNOVA-THRESHOLD-NOT-MET)
                true
            )
            
            ;; For standard missions, simple majority is enough
            (if (> (get approval-count mission) (get rejection-count mission))
                (begin
                    (map-set cosmic-missions mission-id (merge mission {mission-launched: true}))
                    (ok true)
                )
                ERR-MISSION-FAILED
            )
        )
    )
)