#!/bin/bash

# AudioWhisper API Key Setup Script

echo "🔑 AudioWhisper API Key Setup"
echo "============================="
echo ""

# Function to add key to keychain
add_to_keychain() {
    local service=$1
    local account=$2
    local key=$3
    
    # Delete existing key if present
    security delete-generic-password -s "$service" -a "$account" 2>/dev/null
    
    # Add new key
    security add-generic-password -s "$service" -a "$account" -w "$key"
    
    if [ $? -eq 0 ]; then
        echo "✅ API key successfully stored in keychain!"
    else
        echo "❌ Failed to store API key in keychain"
        exit 1
    fi
}

# Choose provider
echo "Which speech-to-text provider would you like to use?"
echo "1) OpenAI Whisper (recommended)"
echo "2) Google Gemini"
echo ""
read -p "Enter choice (1 or 2): " choice

case $choice in
    1)
        echo ""
        echo "📝 Setting up OpenAI Whisper API"
        echo "Get your API key from: https://platform.openai.com/api-keys"
        echo ""
        read -s -p "Enter your OpenAI API key: " api_key
        echo ""
        
        if [ -z "$api_key" ]; then
            echo "❌ API key cannot be empty"
            exit 1
        fi
        
        add_to_keychain "AudioWhisper" "OpenAI" "$api_key"
        
        echo ""
        echo "Note: Make sure useOpenAI is set to true in SpeechToTextService.swift"
        ;;
        
    2)
        echo ""
        echo "📝 Setting up Google Gemini API"
        echo "Get your API key from: https://makersuite.google.com/app/apikey"
        echo ""
        read -s -p "Enter your Gemini API key: " api_key
        echo ""
        
        if [ -z "$api_key" ]; then
            echo "❌ API key cannot be empty"
            exit 1
        fi
        
        add_to_keychain "AudioWhisper" "Gemini" "$api_key"
        
        echo ""
        echo "Note: Make sure useOpenAI is set to false in SpeechToTextService.swift"
        ;;
        
    *)
        echo "❌ Invalid choice. Please run the script again and enter 1 or 2."
        exit 1
        ;;
esac

echo ""
echo "🎉 Setup complete! You can now build and run AudioWhisper."
echo ""
echo "To build the app, run:"
echo "  ./build.sh"