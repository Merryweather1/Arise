# UP DOING — Flutter Productivity App

A modern Flutter rebuild of the Russian productivity app **Up — Doing**.
The goal is to create a **world-class personal productivity platform** combining tasks, habits, goals, Pomodoro focus sessions, and life balance tracking in a single app.

---

# 🚀 Project Overview

**Platform:** Android (Flutter)
**Language:** Dart
**Backend:** Firebase
**State Management:** Riverpod
**Local Database:** Hive
**Cloud Database:** Firestore

This project focuses on:

* Clean architecture
* Offline-first support
* AI-powered productivity insights
* Gamification and motivation systems
* Smooth UI/UX with modern animations

---

# ✨ Core Philosophy

### All-in-One Productivity

Tasks, habits, goals, focus sessions, and life balance tracking in a single system.

### Gamified Motivation

Users earn XP, level up, and unlock achievements for productivity.

### AI-Powered

Smart suggestions, goal breakdowns, and productivity insights.

### Firebase-First

Cloud sync across devices with real-time updates.

### Delightful UX

Smooth animations, polished onboarding, and satisfying interactions.

---

# 📱 App Screens

The app uses **bottom navigation with 5 primary sections**.

| Screen   | Description                                           |
| -------- | ----------------------------------------------------- |
| Home     | Daily overview, XP bar, productivity score            |
| Tasks    | Task management with categories, priorities, subtasks |
| Habits   | Habit tracking with streaks and heatmaps              |
| Goals    | Long-term goals with progress tracking                |
| Pomodoro | Focus timer and productivity sessions                 |

Additional sections:

* Life Balance
* Statistics
* AI Coach
* Achievements
* Account / Profile
* Onboarding
* Paywall / Pro

---

# 🧩 Features

## Tasks

* Create tasks with due dates and priorities
* Subtasks checklist
* Categories and color tags
* Swipe actions (complete / delete)
* Drag to reorder tasks
* Smart scheduling (AI upgrade)

---

## Habits

* Daily / weekly habit tracking
* Streak counter
* Habit calendar heatmap
* Habit statistics
* Custom reminders

---

## Goals

* Long-term goals with deadlines
* Progress tracking
* Subtasks linked to goals
* Cover photos for goals
* AI goal breakdown suggestions

---

## Pomodoro Timer

* Focus timer (default 25 minutes)
* Short and long breaks
* Background timer service
* Session statistics
* Link focus sessions to tasks

---

## Life Balance

Track 8 areas of life:

* Health
* Career
* Finance
* Family
* Social
* Personal Growth
* Fun
* Spirituality

Includes radar charts and historical tracking.

---

## Statistics

* Daily productivity summary
* Habit completion rates
* Weekly productivity charts
* Pomodoro history
* XP progression

---

# 🏆 Gamification

Users earn **XP** by completing tasks, habits, and focus sessions.

Features include:

* Level system
* Achievement badges
* Streak rewards
* Daily login bonus
* Optional leaderboards

---

# 🤖 AI Features

Powered by Gemini API.

* Daily productivity tips
* AI goal breakdown
* Smart task scheduling
* Burnout detection
* Weekly productivity review
* Habit stacking suggestions

---

# 🧱 Tech Stack

## Core Packages

* flutter_riverpod
* go_router
* firebase_core
* firebase_auth
* cloud_firestore
* firebase_storage
* hive_flutter
* flutter_local_notifications
* fl_chart
* lottie
* flutter_slidable

Optional upgrades:

* google_generative_ai
* home_widget
* in_app_purchase

---

# 🏗 Architecture

The app follows **Clean Architecture with feature-based structure**.

```
lib/
 ├── core/
 │   ├── theme
 │   ├── router
 │   ├── firebase
 │   └── services
 │
 ├── features/
 │   ├── tasks/
 │   ├── habits/
 │   ├── goals/
 │   ├── pomodoro/
 │   ├── statistics/
 │   └── life_balance/
 │
 └── main.dart
```

Each feature includes:

```
data/
domain/
presentation/
```

---

# 🔥 Firebase Structure

Firestore collections:

```
users/{uid}/
    tasks
    habits
    goals
    sessions
    lifebalance
    stats
```

Storage:

```
users/{uid}/images/
```

Security rules ensure users can only access their own data.

---

# 🗄 Data Models

Main entities:

* Task
* Habit
* Goal
* CategoryItem
* HabitSchedule
* StatisticsPomo
* StatisticsQualities
* NotificationItem
* TableState (Life Balance)
* UserProfile

---

# 🛠 Build Roadmap

## Phase 1 — Foundation

* Project setup
* Firebase authentication
* Onboarding
* Navigation shell

## Phase 2 — Core Features

* Tasks
* Habits
* Goals
* Dashboard

## Phase 3 — Productivity Tools

* Pomodoro timer
* Life balance
* Statistics

## Phase 4 — Upgrades

* Gamification system
* AI features
* Notifications
* Home screen widgets

## Phase 5 — Polish

* Animations
* Performance optimization
* Subscription system
* Play Store release

---

# 📊 Project Scope

* **Total Screens:** ~24
* **Total Features:** ~65
* **Estimated Build Time:** ~12 weeks (solo)

---

# 📌 Goal

Create a **modern productivity platform** that surpasses the original Up — Doing app with better UX, AI features, and gamified motivation.

---

# 📄 License

Private project — development blueprint.
