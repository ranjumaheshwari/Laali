const express = require('express');
const multer = require('multer');
const speech = require('@google-cloud/speech');
const fs = require('fs');
const path = require('path');

const router = express.Router();

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'audio-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 25 * 1024 * 1024, // 25MB limit
  },
  fileFilter: (req, file, cb) => {
    // Accept audio files
    if (file.mimetype.startsWith('audio/') ||
        file.mimetype === 'video/webm' ||
        file.originalname.match(/\.(wav|mp3|flac|m4a|webm|ogg)$/i)) {
      cb(null, true);
    } else {
      cb(new Error('Only audio files are allowed!'), false);
    }
  }
});

// Initialize Google Cloud Speech client
let speechClient;
try {
  speechClient = new speech.SpeechClient();
} catch (error) {
  console.warn('Google Cloud Speech client not initialized:', error.message);
  console.warn('Make sure GOOGLE_APPLICATION_CREDENTIALS is set or use alternative STT');
}

// POST /api/audio/transcribe
router.post('/transcribe', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file provided' });
    }

    const audioFilePath = req.file.path;
    console.log('Processing audio file:', req.file.filename);

    let transcription = '';

    if (speechClient) {
      // Use Google Cloud Speech-to-Text
      transcription = await transcribeWithGoogleCloud(audioFilePath);
    } else {
      // Fallback: Simple mock transcription for development
      transcription = await transcribeWithMock(audioFilePath);
    }

    // Clean up the uploaded file
    fs.unlinkSync(audioFilePath);

    res.json({
      success: true,
      transcription: transcription,
      language: 'kn-IN', // Kannada
      confidence: speechClient ? 0.85 : 0.5, // Lower confidence for mock
      service: speechClient ? 'google-cloud' : 'mock'
    });

  } catch (error) {
    console.error('Speech-to-text error:', error);

    // Clean up file if it exists
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }

    res.status(500).json({
      error: 'Failed to process audio',
      details: error.message
    });
  }
});

// Google Cloud Speech-to-Text function
async function transcribeWithGoogleCloud(audioFilePath) {
  const audio = {
    content: fs.readFileSync(audioFilePath).toString('base64'),
  };

  const config = {
    encoding: 'LINEAR16', // Adjust based on your audio format
    sampleRateHertz: 16000,
    languageCode: 'kn-IN', // Kannada
    model: 'latest_long', // Use latest model for better accuracy
    useEnhanced: true, // Enable enhanced models
  };

  const request = {
    audio: audio,
    config: config,
  };

  try {
    const [response] = await speechClient.recognize(request);
    const transcription = response.results
      .map(result => result.alternatives[0].transcript)
      .join('\n');

    return transcription || 'No speech detected';
  } catch (error) {
    console.error('Google Cloud Speech error:', error);
    throw new Error('Speech recognition failed: ' + error.message);
  }
}

// Mock transcription function for development/testing
async function transcribeWithMock(audioFilePath) {
  // Get file stats to simulate processing time based on file size
  const stats = fs.statSync(audioFilePath);
  const fileSizeMB = stats.size / (1024 * 1024);

  // Simulate processing delay
  const processingDelay = Math.min(fileSizeMB * 1000, 5000); // Max 5 seconds
  await new Promise(resolve => setTimeout(resolve, processingDelay));

  // Return mock Kannada text for maternal health context
  const mockTranscriptions = [
    'ನನ್ನ ಗರ್ಭಾವಸ್ಥೆಯಲ್ಲಿ ನನಗೆ ಯಾವುದೇ ಸಮಸ್ಯೆಗಳಿವೆ',
    'ನಾನು ಗರ್ಭಿಣಿಯಾಗಿದ್ದೇನೆ, ನನಗೆ ಸಲಹೆ ಬೇಕು',
    'ಮಗುವಿನ ಆರೋಗ್ಯದ ಬಗ್ಗೆ ಮಾಹಿತಿ ಬೇಕು',
    'ಗರ್ಭಧಾರಣೆಯ ಸಮಯದಲ್ಲಿ ಏನು ತಿನ್ನಬೇಕು',
    'ಮಗುವಿನ ಬೆಳವಣಿಗೆಯ ಬಗ್ಗೆ ಕೇಳಲು ಬಯಸುತ್ತೇನೆ'
  ];

  const randomIndex = Math.floor(Math.random() * mockTranscriptions.length);
  return mockTranscriptions[randomIndex];
}

// GET /api/audio/status
router.get('/status', (req, res) => {
  res.json({
    status: 'Speech-to-text service',
    googleCloudConfigured: !!speechClient,
    mockServiceAvailable: true,
    supportedFormats: ['wav', 'mp3', 'flac', 'm4a', 'webm', 'ogg'],
    maxFileSize: '25MB',
    language: 'kn-IN (Kannada)',
    services: {
      primary: speechClient ? 'Google Cloud Speech-to-Text' : 'Mock Service',
      fallback: 'Mock Service (returns sample Kannada text)'
    }
  });
});

module.exports = router;