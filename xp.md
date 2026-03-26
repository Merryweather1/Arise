Complete XP System Audit & Plan
What currently exists (the mess)
In the backend — solid, keep all of it:

UserProfile has willpowerXp, intellectXp, healthXp stored in Firestore ✅
Level math (_xpToLevel, _nextLevelXp, _levelStartXp) is correct ✅
willpowerLevel/Progress, intellectLevel/Progress, healthLevel/Progress getters work ✅
UserRepository.addXp() uses FieldValue.increment() — atomic, correct ✅
Every TaskModel, HabitModel, GoalModel has xpSphere + xpReward fields ✅
XP is awarded in providers on task complete, habit toggle, goal complete ✅

In the backend — broken:

Pomodoro calls PomodoroRepository.logSession() directly, bypassing pomodoroActionsProvider.logSession() where XP is awarded → Pomodoro never gives XP ❌
setDone(task, true) awards XP even if task was already done → double XP exploit ❌
No levelForSphere() helper on UserProfile ❌

In the UI — what exists:

_XpCard on home screen shows combined level + 3 sphere pips with real data ✅
_combinedLevel() and _levelStartXp() are duplicated inside _XpCard instead of using model methods ❌
No XP popup when you complete anything ❌
No level-up celebration ❌
No XP feedback anywhere except the home card ❌
No profile/settings screen showing XP breakdown ❌


The Plan — 4 clean steps
Step 1 — Fix the 2 backend bugs (providers + pomodoro)
In app_providers.dart, setDone:
// Before:
if (done) await UserRepository.addXp(...)

// After:
if (done && !task.done) await UserRepository.addXp(...)
In pomodoro_screen.dart, replace direct PomodoroRepository.logSession() call with ref.read(pomodoroActionsProvider.notifier).logSession() — one line change.
Step 2 — Add XpEvent system to providers
Add a simple event notifier to app_providers.dart. When XP is awarded anywhere, fire an event so the UI can react:
dartclass XpEvent {
  final XpSphere sphere;
  final int amount;
  final bool isLevelUp;
  final int newLevel;
  XpEvent({required this.sphere, required this.amount,
           this.isLevelUp = false, this.newLevel = 0});
}

final xpEventProvider = StateProvider<XpEvent?>((ref) => null);
Then in every notifier that awards XP, after addXp(), detect level-up by comparing before/after and fire the event. Add levelForSphere(XpSphere) helper to UserProfile to make this clean.
Step 3 — XP popup overlay in app_shell.dart
app_shell.dart wraps every screen. Add a listener for xpEventProvider there. When an event fires, show a small overlay popup using OverlayEntry or a Stack on the Scaffold. Two variants:

Normal XP: Small floating pill "🔥 +10 XP" — slides up 40px, fades out over 1.5s. Uses flutter_animate which is already in pubspec.
Level up: Full modal sheet showing "LEVEL UP! 🔥 Willpower Level 5" with animated XP bar. Dismisses with a button.

Step 4 — Home screen XP card cleanup
Remove the duplicated _combinedLevel and _levelStartXp static methods from _XpCard — these already exist in UserProfile. Make _XpCard use the model getters directly. Add small progress bars to the 3 sphere pips showing individual progress.

The Complete Flow — How It Was Supposed To Work
Step 1 — User completes a task
User swipes right on a task card or taps the checkbox. The screen calls:
dartref.read(taskActionsProvider.notifier).setDone(task, true)
Step 2 — Provider checks and awards XP
TaskNotifier.setDone() in app_providers.dart:
dartFuture<void> setDone(TaskModel task, bool done) async {
  await TaskRepository.setDone(_uid, task.id, done);
  if (done && !task.done) {  // ← the !task.done check prevents double-awarding
    await UserRepository.addXp(_uid, task.xpSphere, task.xpReward);
  }
}
task.xpSphere is whatever sphere was set when the task was created — defaults to XpSphere.willpower. task.xpReward defaults to 10.
Step 3 — Firestore atomic increment
UserRepository.addXp() in firestore_service.dart:
dart_db.collection('users').doc(uid).update({
  'willpowerXp': FieldValue.increment(10)
})
```

`FieldValue.increment` is atomic — even if two completions fire simultaneously, Firestore handles it safely. No race condition possible.

### Step 4 — Real-time stream updates the UI

`userProfileProvider` is a `StreamProvider` listening to the user document. The moment Firestore updates `willpowerXp`, the stream fires. `UserProfile` is rebuilt with the new XP value. All `willpowerLevel`, `willpowerProgress` getters recompute automatically. The home screen XP card re-renders with the new values.

---

## What Each Action Earns

| Action | Amount | Sphere |
|--------|--------|--------|
| Complete any task | 10 XP | `task.xpSphere` (set when created, default: Willpower) |
| Toggle habit done | 15 XP | `habit.xpSphere` (set when created, default: Willpower) |
| Complete a goal | 50 XP | `goal.xpSphere` (set when created, default: Willpower) |
| Finish Pomodoro session | `minutes ÷ 5` XP | Always Willpower (25 min = 5 XP, 50 min = 10 XP) |

---

## The Level Math

Each sphere starts at Level 1 with 0 XP. The XP needed to reach each next level increases by 25% each time:
```
Level 1 → 2:   100 XP needed
Level 2 → 3:   125 XP needed
Level 3 → 4:   156 XP needed
Level 4 → 5:   195 XP needed
Level 5 → 6:   244 XP needed
Level 6 → 7:   305 XP needed
...
Concrete example: You complete 10 tasks in a day (all Willpower, 10 XP each = 100 XP). Your Willpower sphere goes from Level 1 to Level 2 exactly. The next level requires 125 XP.
Another example: You complete a 7-habit day (all 15 XP each = 105 XP total). Willpower Level 1 → 2, with 5 XP carried over toward Level 3.
Each sphere levels independently. You can be Willpower L8, Intellect L3, Health L1 — totally normal if you complete lots of tasks but rarely do health habits.

What Was Broken (Plain English)
Bug 1 — Pomodoro: The pomodoro screen calls PomodoroRepository.logSession() directly, skipping the pomodoroActionsProvider.logSession() where the XP award line lives. So pomodoro sessions save to Firestore correctly but zero XP is ever given. The session counting and statistics work fine — only XP is broken.
Bug 2 — Double XP: setDone(task, true) checks if (done) but not if (done && !task.done). If a task is already marked done and something calls setDone again (e.g. swipe gesture fires twice, or user completes then undoes then completes again), XP gets awarded every time. Missing one word: !task.done.

What Was Missing (The UI Side)
The backend works completely — XP goes into Firestore, levels calculate correctly, the home screen XP card reads real data. But the user has zero feedback that any of this is happening. It's completely invisible.
What needs to be built:
XP popup — when you complete a task, a small pill floats up near the action: "🔥 +10 XP". Slides up, fades out in 1.5 seconds. User feels the reward immediately.
Level-up screen — when completing an action pushes a sphere to the next level, a celebration modal appears: big sphere emoji, "LEVEL UP!", the new level number, animated XP bar filling up. One button to dismiss. This is the moment that makes the whole system feel real.
XP event system — the glue between backend and UI. A simple StateProvider<XpEvent?> in providers. Every time XP is awarded, the notifier also fires an XpEvent. app_shell.dart listens to it and shows the appropriate popup. Without this pipe, the backend and UI have no way to communicate that something just happened.

So to answer your question directly — if everything was fixed and complete, this is what would happen:
You tap the checkbox on "Finish Flutter course" (Learning category, Intellect sphere, 10 XP). The checkmark animates. A small "🧠 +10 XP" pill floats up and fades away. If that 10 XP pushed your Intellect from Level 2 to Level 3, a celebration sheet slides up showing "LEVEL UP! 🧠 Intellect is now Level 3". You tap "Let's go!" and it dismisses. The home screen XP card has already silently updated showing the new progress bar position. Everything connected, everything felt.

The Problem With Defaults
Right now when you create a task, this is what gets saved:
dartxpSphere: XpSphere.willpower,  // hardcoded default
xpReward: 10,                   // hardcoded default
And when you create a habit:
dartxpSphere: XpSphere.willpower,  // hardcoded default
xpReward: 15,
```

**So literally everything goes to Willpower, always.** Health and Intellect never receive XP because there's no logic anywhere that routes based on category. The spheres exist, the math works, but they're always empty.

---

## How It Should Work

There are two approaches. Let's think about which one makes sense for your app:

**Option A — Automatic routing based on category**
The app automatically decides which sphere gets XP based on what category the task/habit/goal belongs to. User never thinks about it.
```
Work, Career, Finance        → 🔥 Willpower
Learning, Mind               → 🧠 Intellect  
Health, Fitness              → ❤️ Health
Personal, Family, Social     → 🔥 Willpower (default)
Errands                      → 🔥 Willpower (default)
Option B — User picks the sphere manually
When creating a task/habit/goal, there's a selector where the user chooses which sphere to feed. Full control.
Option C — Both
Auto-routing as the default, but user can override it when creating the item.

My Recommendation: Option C
Auto-routing is the right default because:

Most users won't know what a "sphere" is at first
It makes the system feel intelligent and automatic
Categories already exist and have clear meanings

But manual override matters because:

"Read a book" could be Learning (Intellect) or Personal (Willpower) depending on the user
A "Finance" task could feel like discipline (Willpower) to one person, strategy (Intellect) to another
Power users want control


The Full Category → Sphere Mapping
Here's what I'd implement:
dartstatic XpSphere sphereForCategory(String category) {
  switch (category.toLowerCase().trim()) {
    
    // 🧠 Intellect — mental growth, learning, strategy
    case 'learning':
    case 'mind':
    case 'career':
    case 'education':
    case 'study':
      return XpSphere.intellect;

    // ❤️ Health — physical and mental wellbeing  
    case 'health':
    case 'fitness':
    case 'sport':
    case 'wellness':
    case 'medical':
      return XpSphere.health;

    // 🔥 Willpower — everything else: discipline, life admin, relationships
    default: // Personal, Work, Finance, Family, Social, Errands, etc.
      return XpSphere.willpower;
  }
}
```

This lives as a static method on `XpSphere` extension in `app_models.dart`.

---

## How XP Reward Amount Should Scale Too

Right now everything is flat — every task is 10 XP regardless. That's boring. Here's a better system:

**Tasks — based on priority:**
```
Priority 1-3 (Low)      →  5 XP
Priority 4-6 (Medium)   → 10 XP
Priority 7-8 (High)     → 15 XP
Priority 9-10 (Urgent)  → 20 XP
```

**Habits — fixed but higher because consistency is the point:**
```
Any habit completion     → 15 XP (always, consistency is what matters)
```

**Goals — based on how ambitious the goal is (could be set manually or fixed):**
```
Any goal completion      → 50 XP (big win, always rewarded well)
```

**Pomodoro — already correct:**
```
25 min session           →  5 XP
50 min session           → 10 XP
Any duration             → minutes ÷ 5

Concrete Examples With The Fixed System
You create "Read 20 pages" in Learning category:

Auto-routing fires: Learning → Intellect
Priority 4 → 10 XP
When you complete it: intellectXp += 10

You create "Go for a run" in Fitness category:

Auto-routing fires: Fitness → Health
Priority 6 → 10 XP
When you complete it: healthXp += 10

You create "File tax return" in Finance category:

Finance → Willpower (discipline to do boring adult things)
Priority 8 → 15 XP
When you complete it: willpowerXp += 15

You create a habit "Meditate daily" in Health category:

Auto-routing: Health → Health sphere
Toggle it done: healthXp += 15

You want to override: You create "Plan business strategy" in Work category. Work defaults to Willpower, but you think this is an Intellect activity. You tap the sphere selector and switch to 🧠. Override saved with the task.

What Needs To Change In The Code
app_models.dart — add sphereForCategory() and xpForPriority() static helpers to the XpSphereExt extension.
firestore_service.dart — TaskRepository.create() and HabitRepository.create() should call sphereForCategory(category) to set the default sphere, and xpForPriority(priority) for tasks. Instead of hardcoded XpSphere.willpower and 10.
tasks_screen.dart — the task editor needs a sphere selector UI (3 tappable chips: 🔥 🧠 ❤️). Pre-selected automatically based on category. User can override. When category changes, sphere auto-updates unless user manually overrode it.
habits_screen.dart — same sphere selector in habit editor, auto-set from category.
goals_screen.dart — same in goal editor.

The User Experience Flow
User opens "New Task":

Types title: "Study Flutter architecture"
Selects category: Learning
Sphere auto-selects to 🧠 Intellect — user sees this happen
Sets priority: 7
XP reward shows: 15 XP — user sees this
Saves

User completes the task → intellectXp += 15 → Intellect bar on home screen fills up.
User can also manually change the sphere if they disagree with the auto-selection — just tap a different pip.

Auto-routing in plain English
When you create a task, you already pick a category — Work, Learning, Health, etc.
Auto-routing means: the app reads that category and automatically decides which XP sphere to feed.
You never touch the sphere selector at all in most cases. It just happens silently in the background.

One concrete walkthrough
You open New Task. You type "Read Clean Code book". You pick category Learning. You hit Save.
Behind the scenes the app runs:
category = "Learning"
→ Learning maps to Intellect
→ xpSphere = Intellect
→ xpReward = 10 (based on priority)
You complete the task. intellectXp += 10. Done. You never saw a sphere selector. You never made a decision. It just worked.

The mapping — what routes to what
Learning, Mind, Career       →  🧠 Intellect
Health, Fitness, Wellness    →  ❤️ Health
Everything else              →  🔥 Willpower
(Work, Personal, Finance, 
 Family, Social, Errands...)
That's it. Three buckets. Category decides the bucket automatically.

Where Option C adds the manual override
Option C just means there's also a small selector in the editor:
┌─────────────────────────────┐
│ XP Sphere                   │
│  [🔥 Willpower]  🧠  ❤️    │  ← auto-selected, user can tap to change
└─────────────────────────────┘
When you pick a category, the highlighted sphere updates automatically. But if you disagree — say you put "Business strategy" under Work but personally feel it's an Intellect activity — you just tap 🧠 and it overrides.
The auto-routing is the default. The selector is just an escape hatch for the 10% of cases where you want something different.

Why this matters
Without this, everything feeds Willpower forever. Health and Intellect stay at Level 1 permanently no matter what you do. The 3-sphere system becomes pointless — it's just one sphere with extra visual decoration.
With auto-routing, the spheres naturally diverge based on how you actually live. Someone who studies a lot will have high Intellect. Someone who exercises daily will have high Health. The profile screen starts telling a real story about who you are.