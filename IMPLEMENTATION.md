# NoteAI Implementation Details

## Overview

NoteAI is a minimalistic, AI-powered contact management app designed specifically for networking events. It allows users to add contacts using natural language, automatically categorizes them, and provides powerful search capabilities.

## Architecture

The app follows a modern MVVM architecture with the following components:

### Models
- `User`: Represents the user profile
- `Contact`: Represents a contact with metadata
- `Label`: Represents categories for contacts
- `Subscription`: Handles in-app purchase information

### Services
- `SupabaseService`: Handles database connections
- `AuthService`: Manages authentication with Google and Apple
- `AIService`: Integrates with OpenAI for natural language processing
- `ContactService`: Manages contact operations
- `SubscriptionService`: Handles in-app purchases

### Views
- `AuthView`: Login screen with Google and Apple Sign-In
- `OnboardingView`: First-time user experience and contact import
- `MainView`: Main interface for adding and viewing contacts
- `ContactDetailView`: Detailed view of a contact
- `SubscriptionView`: Subscription management

## Database Schema

The Supabase database uses the following tables:
- `contacts`: Stores contact information
- `labels`: Stores category labels
- `contact_labels`: Many-to-many relationship between contacts and labels
- `user_preferences`: User-specific settings
- `app_subscriptions`: Subscription information

## Features Implemented

1. **Authentication Flow**
   - Google Sign-In integration
   - Apple Sign-In integration
   - User profile management

2. **AI-Powered Contact Creation**
   - Natural language contact information extraction
   - Automatic label suggestion
   - Seamless iPhone Contacts app integration

3. **Smart Search**
   - Search by name, label, or description
   - Natural language query processing
   - Relevance-based results

4. **Contact Organization**
   - Custom label creation
   - Automatic labeling based on description
   - Visual label management

5. **Subscription Management**
   - Monthly subscription with StoreKit
   - Development mode for testing
   - Premium features gating

## Next Steps

1. **Configuration Required**
   - Set up authentication providers in Supabase
   - Add OpenAI API key
   - Configure Google and Apple Sign-In
   - Set up StoreKit product

2. **Testing**
   - Test authentication flow
   - Test contact creation with different inputs
   - Test search functionality
   - Test subscription flow

3. **Future Enhancements**
   - Improved AI model integration
   - Enhanced contact visualization
   - Better search with embeddings
   - Additional premium features

## Security Considerations

- API keys should be stored securely, not hardcoded
- User data is protected with Supabase Row Level Security
- Authentication uses industry-standard OAuth flows
- Contacts sync requires explicit user permission
