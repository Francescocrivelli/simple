# NoteAI - AI-Powered Contact Manager

NoteAI is a minimalistic iOS application designed for efficient contact management at networking events. It uses AI to automatically categorize and organize your contacts based on natural language descriptions.

## Features

- **Natural Language Contact Creation**: Simply describe the person you met
- **AI-Powered Labeling**: Automatic categorization of contacts 
- **Smart Search**: Find contacts using natural language
- **Google & Apple Sign-In**: Easy authentication
- **Contact Sync**: Import your existing iPhone contacts

## Setup Instructions

### Prerequisites

- Xcode 14.0+
- iOS 15.0+ device or simulator
- Swift Package Manager
- Supabase account
- OpenAI API key

### Configuration Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/Francescocrivelli/simple.git
   cd simple
   ```

2. **Database Setup**
   - Run the SQL schema in the `supabase/schema.sql` file in your Supabase project SQL editor
   - Make sure authentication providers (Google & Apple) are enabled in your Supabase project

3. **API Keys**
   - Replace the OpenAI API placeholder in `AIService.swift`
   - Update the Supabase URL and key in `SupabaseService.swift` if needed

4. **Google Sign-In Setup**
   - Create a new project in Google Cloud Console
   - Set up OAuth credentials for iOS
   - Add your Client ID to Info.plist
   - Configure URL schemes in Xcode

5. **Apple Sign-In Setup**
   - Enable Sign in with Apple capability in Xcode
   - Add the domain to your Apple Developer account

6. **StoreKit Configuration**
   - Create a StoreKit configuration file for testing
   - Add your product ID to `SubscriptionService.swift`

7. **Build and run the app**
   ```bash
   open simple.xcodeproj
   ```

## Project Structure

```
simple/
├── Models/             # Data models
├── Services/           # Business logic and API services
├── Views/              # SwiftUI views
└── supabase/           # Database schema
```

## Usage

1. Sign in with Apple or Google
2. Import your existing contacts or start fresh
3. Add new contacts by describing them in natural language
4. Search your contacts using natural language queries
5. Organize contacts with AI-suggested labels

## License

This project is licensed under the MIT License - see the LICENSE file for details.
