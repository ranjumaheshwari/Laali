# Audio API Documentation

## Base URL
`http://localhost:3000/api/audio`

## Endpoints

### POST /transcribe
Transcribes audio files to Kannada text.

**Request:**
- Method: POST
- Content-Type: multipart/form-data
- Body: Form data with 'audio' field containing the audio file

**Supported Audio Formats:**
- WAV, MP3, FLAC, M4A, WebM, OGG
- Maximum file size: 25MB

**Response:**
```json
{
  "success": true,
  "transcription": "ನನ್ನ ಗರ್ಭಾವಸ್ಥೆಯಲ್ಲಿ ನನಗೆ ಯಾವುದೇ ಸಮಸ್ಯೆಗಳಿವೆ",
  "language": "kn-IN",
  "confidence": 0.85,
  "service": "google-cloud"
}
```

**Error Response:**
```json
{
  "error": "Failed to process audio",
  "details": "Error message"
}
```

### GET /status
Returns the status of the speech-to-text service.

**Response:**
```json
{
  "status": "Speech-to-text service",
  "googleCloudConfigured": true,
  "mockServiceAvailable": true,
  "supportedFormats": ["wav", "mp3", "flac", "m4a", "webm", "ogg"],
  "maxFileSize": "25MB",
  "language": "kn-IN (Kannada)",
  "services": {
    "primary": "Google Cloud Speech-to-Text",
    "fallback": "Mock Service (returns sample Kannada text)"
  }
}
```

## Usage Examples

### JavaScript (Frontend)
```javascript
const formData = new FormData();
formData.append('audio', audioFile);

fetch('http://localhost:3000/api/audio/transcribe', {
  method: 'POST',
  body: formData
})
.then(response => response.json())
.then(data => {
  console.log('Transcription:', data.transcription);
})
.catch(error => console.error('Error:', error));
```

### cURL
```bash
curl -X POST http://localhost:3000/api/audio/transcribe \
  -F "audio=@/path/to/audio.wav"
```

## Setup

1. Install dependencies:
```bash
npm install
```

2. Copy environment variables:
```bash
cp .env.example .env
```

3. For production speech-to-text, set up Google Cloud:
   - Create a Google Cloud project
   - Enable the Speech-to-Text API
   - Create a service account key
   - Set GOOGLE_APPLICATION_CREDENTIALS in .env

4. Start the server:
```bash
npm start
```