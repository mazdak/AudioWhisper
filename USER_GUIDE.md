# AudioWhisper User Guide - Transcription History

## Overview

AudioWhisper automatically saves your transcriptions to a searchable history, allowing you to review, search, and manage past recordings. This guide explains how to use the transcription history feature effectively.

## Accessing Transcription History

There are two ways to open the Transcription History window:

### 1. From the Menu Bar
- Click on the AudioWhisper icon in your menu bar
- Select **"Transcription History"** from the dropdown menu
- Or use the keyboard shortcut: **⌘H** (Command + H)

### 2. From Settings
- Open AudioWhisper Settings (⌘,)
- Navigate to the **History** tab
- Click the **"View History"** button

## Using the History Window

### Window Layout

The Transcription History window contains:
- **Search Bar**: Located at the top for filtering transcriptions
- **Records List**: Displays all your transcriptions with newest first
- **Action Menu**: Click the ellipsis (⋯) button in the toolbar for additional options

### Viewing Transcriptions

Each transcription record displays:
- **Date and Time**: When the recording was made
- **Provider Badge**: Shows which service was used (OpenAI, Gemini, Local, or Parakeet)
- **Duration**: How long the recording was (if available)
- **Model Used**: Which AI model processed the transcription (for local transcriptions)
- **Transcription Text**: The actual transcribed content (up to 4 lines preview)

## Searching Transcriptions

### Using the Search Bar

1. Click in the search field or press **⌘F** (Command + F) to focus
2. Type your search terms - the list updates instantly
3. Search matches against:
   - Transcription text content
   - Provider names (e.g., "openai", "local")
   - Model names (e.g., "base", "large")

### Search Tips

- Search is case-insensitive
- Partial word matches are supported
- Clear search by clicking the X button or pressing **Escape**

## Managing Transcriptions

### Selecting Records

- **Single Selection**: Click the circle icon next to any record
- **Multiple Selection**: Hold Shift or Command while clicking
- **Select All**: Press **⌘A** (Command + A) or use the menu

### Actions on Selected Records

When records are selected, you can:
- **Copy**: Press **⌘C** to copy selected transcriptions to clipboard
- **Delete**: Press **Delete** key to remove selected records

### Individual Record Actions

Hover over any record to reveal action buttons:
- **Copy Button** (📄): Copy individual transcription to clipboard
- **Delete Button** (🗑️): Delete individual record

### Deleting Records

- **Single Record**: Hover and click the trash icon, then confirm
- **Multiple Records**: Select records and press Delete key
- **Clear All History**: Use the menu (⋯) > "Clear All History"

**Note**: Deletions are permanent and cannot be undone.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **⌘H** | Open History window (from menu bar) |
| **⌘F** | Focus search field |
| **⌘A** | Select all visible records |
| **⌘C** | Copy selected records |
| **Delete** | Delete selected records |
| **Escape** | Clear search or deselect all |

## Privacy and Data Storage

### Data Location
- Transcriptions are stored locally on your Mac
- No data is sent to external servers for history storage
- Data is managed using Apple's SwiftData framework

### History Settings

Configure history behavior in Settings > History:
- **Enable/Disable History**: Toggle whether transcriptions are saved
- **Retention Period**: Choose how long to keep records:
  - 1 Week
  - 1 Month
  - 3 Months
  - Forever

### Data Cleanup
- AudioWhisper automatically removes expired records based on your retention settings
- Manual cleanup is available via "Clear All History"

## Tips for Effective Use

1. **Quick Access**: Use ⌘H from anywhere to quickly open history
2. **Batch Operations**: Select multiple records for efficient copying or deletion
3. **Search Filters**: Use provider names to filter by transcription service
4. **Text Selection**: Click and drag to select specific text within transcriptions
5. **Double-Click**: Double-click any record to quickly copy its content

## Troubleshooting

### History Not Saving
- Check that history is enabled in Settings > History
- Ensure AudioWhisper has necessary permissions

### Search Not Working
- Try simpler search terms
- Check spelling of search queries
- Clear search and try again

### Window Not Opening
- Restart AudioWhisper
- Check for any error messages
- Ensure you're using the latest version

## Export and Backup

While AudioWhisper doesn't have a built-in export feature, you can:
1. Select all records (⌘A)
2. Copy them (⌘C)
3. Paste into any text editor or document
4. Save the file for backup

The copied format includes timestamps and provider information for each transcription.

---

For additional help or to report issues, please visit the AudioWhisper GitHub repository.