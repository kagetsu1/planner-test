# 🎓 Planora

**Your Academic Journey, Simplified**

A comprehensive student productivity suite for iPhone and iPad that seamlessly integrates with your academic life through Moodle, calendar management, and intelligent task tracking.

![Planora](https://img.shields.io/badge/iOS-26.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-2.0-red.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ Features

### 📅 **Smart Calendar Integration**
- **Moodle Sync**: Automatically import class schedules and deadlines
- **Custom Week Start**: Choose your preferred week start day (Sunday-Saturday)
- **Multi-Slot Classes**: Support for multiple class slots per course
- **Room & Instructor Management**: Track different rooms and instructors for each slot
- **iCloud Calendar Sync**: Seamless integration with Apple Calendar
- **Google Calendar Integration**: Connect with Google Calendar (coming soon)

### 🎯 **Course Management**
- **Multiple Instructors**: Support for professors, TAs, and adjunct instructors
- **Class Types**: Lecture, Tutorial, Lab, Studio, Seminar, Workshop
- **Attendance Tracking**: Mark attendance for each class session
- **GoodNotes Integration**: View course notebooks via web links
- **Course Analytics**: Track performance and attendance statistics

### ✅ **Task & Assignment Management**
- **Moodle Integration**: Automatic assignment import from Moodle
- **Smart Reminders**: Customizable notification times
- **Priority Levels**: Organize tasks by importance
- **Due Date Tracking**: Never miss a deadline
- **Course Association**: Link tasks to specific courses

### 📊 **Grade Analytics**
- **Moodle Grade Sync**: Import grades directly from Moodle
- **Manual Entry**: Add grades manually for non-Moodle courses
- **Performance Reports**: Visual analytics and progress tracking
- **Grade Categories**: Organize by assignment type (quiz, project, exam)
- **GPA Calculation**: Automatic GPA tracking

### 🔄 **Habit Tracking**
- **Custom Habits**: Create personalized study habits
- **Frequency Tracking**: Daily, weekly, or custom schedules
- **Progress Visualization**: Track your consistency
- **Reminders**: Stay on top of your habits
- **Streak Tracking**: Build momentum with streak counters

### 📝 **Journal & Notes**
- **Mood Tracking**: Record your daily mood and energy levels
- **Reflection Prompts**: Guided journaling for academic growth
- **Tag System**: Organize entries by topic or course
- **Rich Text Support**: Format your thoughts beautifully
- **Search & Filter**: Find past entries quickly

### ⏱️ **Focus Timer (Pomodoro)**
- **Customizable Sessions**: Set your preferred work/break intervals
- **Course Integration**: Link focus sessions to specific courses
- **Statistics**: Track your focus time and productivity
- **Background Audio**: Continue timing even when app is in background
- **Smart Notifications**: Gentle reminders for breaks

### 🔐 **Secure Authentication**
- **Apple Sign-In**: Secure authentication with Apple ID
- **Google Sign-In**: Alternative authentication option
- **Guest Mode**: Use app without account (limited features)
- **Cross-Device Sync**: Access your data on all devices

### ☁️ **Decentralized Backup**
- **iCloud Integration**: Automatic encrypted backups
- **No Server Required**: Your data stays on your devices and iCloud
- **Device-Specific Encryption**: Only you can access your data
- **Automatic Sync**: Seamless data synchronization
- **Manual Backup/Restore**: Full control over your data

### 📱 **iOS Widgets**
- **Next Class Widget**: See upcoming class details at a glance
- **Tasks Widget**: Quick view of pending assignments
- **Events Widget**: Today's schedule overview
- **Multiple Sizes**: Small, medium, and large widget options

### 🎨 **Personalization**
- **Accent Colors**: Choose from 9 beautiful color themes
- **Dark/Light Mode**: Automatic or manual theme switching
- **Custom Reminders**: Set default reminder times
- **Haptic Feedback**: Enhanced tactile experience
- **Accessibility**: Full VoiceOver and accessibility support

## 🚀 Getting Started

### Prerequisites
- iOS 26.0+ / iPadOS 26.0+ (2025)
- iPhone or iPad
- Apple ID (for full features)
- iCloud account (for backup and sync)

### Installation

#### From App Store (Recommended)
1. Search for "Planora" in the App Store
2. Tap "Get" or "Download"
3. Authenticate with your Apple ID
4. Launch the app and sign in

#### Development Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/planora.git
cd aera-flow

# Open in Xcode
open Planora.xcodeproj

# Build and run
# Select your target device and press Cmd+R
```

### Initial Setup
1. **Sign In**: Use Apple ID or Google account for full features
2. **Calendar Access**: Grant calendar permissions for class sync
3. **Moodle Setup**: Configure your Moodle connection (optional)
4. **Customize**: Set your accent color and week start day
5. **Backup**: Enable iCloud backup for data safety

## 🔧 Configuration

### Moodle Integration
1. Go to Settings → Integrations → Moodle
2. Enter your Moodle URL (e.g., `https://your-university.edu/moodle`)
3. Enter your username and password
4. Tap "Connect" to sync your courses

### Calendar Settings
1. Go to Settings → Appearance
2. Choose your preferred accent color
3. Set your week start day
4. Configure default reminder times

### Backup Settings
1. Go to Settings → Backup & Sync
2. Enable automatic iCloud backup
3. Set backup frequency (hourly/daily)
4. Test backup and restore functionality

## 📱 Supported Devices

### iPhone
- iPhone 15 Pro Max
- iPhone 15 Pro
- iPhone 15 Plus
- iPhone 15
- iPhone 14 series
- iPhone 13 series
- iPhone 12 series
- iPhone 11 series
- iPhone SE (2nd & 3rd generation)

### iPad
- iPad Pro 12.9" (6th generation)
- iPad Pro 11" (4th generation)
- iPad Air (5th generation)
- iPad (10th generation)
- iPad mini (6th generation)

## 🛠️ Technical Details

### Architecture
- **Framework**: SwiftUI 2.0
- **Language**: Swift 5.0
- **Data Storage**: Core Data with CloudKit
- **Authentication**: Apple Sign-In, Google Sign-In
- **Backup**: iCloud with AES-GCM encryption
- **Widgets**: WidgetKit

### Dependencies
- **Core Data**: Local data persistence
- **CloudKit**: iCloud synchronization
- **EventKit**: Calendar integration
- **UserNotifications**: Push notifications
- **AuthenticationServices**: Apple Sign-In
- **CryptoKit**: Data encryption

### Security Features
- **End-to-End Encryption**: All data encrypted locally
- **Device-Specific Keys**: Only your device can decrypt data
- **No Server Storage**: Data never leaves your control
- **Privacy-First**: Minimal data collection
- **Secure Authentication**: Industry-standard OAuth

## 📊 Performance

### Memory Usage
- **Typical**: 50-100 MB
- **Peak**: 150-200 MB (during sync operations)

### Battery Impact
- **Background**: Minimal (only during sync)
- **Active Use**: Standard for productivity apps
- **Widgets**: Low battery impact

### Storage Requirements
- **App Size**: ~50 MB
- **User Data**: Varies by usage (typically 10-100 MB)
- **iCloud**: Automatic management

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Code Style
- Follow Swift style guidelines
- Use SwiftUI best practices
- Maintain accessibility standards
- Add documentation for new features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Documentation
- [User Guide](docs/USER_GUIDE.md)
- [API Documentation](docs/API.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

### Contact
- **Email**: support@planora.app
- **Website**: https://planora.app
- **Twitter**: [@PlanoraApp](https://twitter.com/PlanoraApp)

### Bug Reports
Please report bugs through:
1. In-app feedback (Settings → About → Send Feedback)
2. GitHub Issues
3. Email support

## 🗺️ Roadmap

### Version 1.1 (Q1 2025)
- [ ] Google Calendar full integration
- [ ] Zoom/Google Meet integration
- [ ] Advanced analytics dashboard
- [ ] Study group features

### Version 1.2 (Q2 2025)
- [ ] macOS companion app
- [ ] Advanced Moodle features
- [ ] AI-powered study recommendations
- [ ] Export to PDF/CSV

### Version 2.0 (Q3 2025)
- [ ] Collaborative features
- [ ] Advanced scheduling AI
- [ ] Integration with more LMS platforms
- [ ] Offline-first architecture

## 🙏 Acknowledgments

- **Apple**: For SwiftUI and iOS platform
- **Moodle**: For educational technology standards
- **Open Source Community**: For inspiration and tools
- **Beta Testers**: For valuable feedback and testing

---

**Made with ❤️ for students worldwide**

*Empowering students to take control of their academic journey, one day at a time.*
