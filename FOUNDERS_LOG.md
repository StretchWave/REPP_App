# Founder's Log - Formula of Grief

> **Mission:** Documenting the technical evolution of the fitness-to-game progression system.

## System Architecture: REPP Integration
**Core Loop:** Mobile App (REPP) &rarr; Supabase (Temporary Buffer) &rarr; Unreal Engine Game

### Component Overview
*   **REPP (Mobile App):**
    *   **Technology:** Uses **Google ML Kit** for real-time pose detection to verify workout form and completion.
    *   **Stats Tracked:** Strength, Agility, Endurance.
*   **Data Flow Strategy:**
    1.  **Validation:** Workout data is strictly validated on the client-side via ML Kit state machines.
    2.  **Transmission:** Validated "packets" are stored temporarily in **Supabase**.
    3.  **Consumption:** The Unreal Engine client polls Supabase, consumes the packet to update character stats, and clears the record (Mailbox Pattern).

---

## [2026-02-09] Establishing Core Mechanics & Anti-Cheat

### 1. Problem Space & Solutions

#### A. The Integrity Challenge (Anti-Cheat)
*   **Problem:** Users can easily exploit accelerometer-based input by shaking the device or performing "half-reps," inflating their in-game Strength stat without physical effort. This destabilizes the game economy.
*   **Solution:** Implemented a **Joint-Angle State Machine** using ML Kit. A rep is only registered if specific biomechanical thresholds are met (Full Extension &rarr; Full Depth &rarr; Full Extension).

#### B. The Progression Challenge (Adaptive Difficulty)
*   **Problem:** Static workout routines fail to accommodate varying fitness levels, leading to either frustration or boredom.
*   **Solution:** Introduced a **Calibration System**. The app calculates a baseline attribute (e.g., Strength) based on user performance over a set duration. Future workouts are dynamically scaled to this baseline.

#### C. The Engagement Challenge (Gamification)
*   **Problem:** Traditional fitness apps often suffer from high churn due to a lack of tangible, immediate rewards.
*   **Solution:** **Direct Stat Translation.** Physical improvement directly correlates to in-game power. A user who increases their real-world bench press capacity will see a proportional increase in their in-game character's Strength.

### 2. Core Logic: Push-Up Validation Algorithm

**Context:** Reliably quantizing the "Standard Push-Up" to drive the **Strength** stat.

*   **Biomechanics (The Formula):**
    *   We track the **Elbow Joint Angle** (Shoulder-Elbow-Wrist vertex).
    *   **State A (Locked Out):** Angle > **160°**.
    *   **State B (Depth):** Angle < **90°**.
    *   **Valid Rep Cycle:** State A &rarr; State B &rarr; State A.

*   **Reward Logic:**
    *   **Base Reward:** 1 Valid Rep = **10 Strength XP**.
    *   **Quality Multiplier:** If `TimeUnderTension` > 2.0s per rep, apply a **1.2x Multiplier**. This encourages controlled, safe form over speed.

### 3. Architectural Decisions
*   **Why ML Kit?** Pose detection offers superior fidelity compared to raw accelerometer data. It allows us to visualize limb geometry rather than just device acceleration, making form validation significantly more robust.
*   **Why Transient Storage?** We treat Supabase as a high-throughput "mailbox" rather than a persistent history log. Unconsumed packets are transient. This keeps storage costs minimal and reduces data liability.

### 4. Security & Future Considerations

*   **Vulnerability:** API Spoofing. While Row Level Security (RLS) is active, a sophisticated user could potentially replay or construct fake "Rep Completion" requests.
*   **Proposed Mitigation:** **Server-Side Rate Limiting / Sanity Checks**.
    *   *Implementation:* Reject packets claiming physically impossible performance (e.g., 50 reps in 10 seconds).
    *   *Timeline:* Scheduled for Next Sprint.

---
