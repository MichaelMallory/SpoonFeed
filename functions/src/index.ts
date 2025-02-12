import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { OpenAI } from 'openai';
import * as ffmpeg from 'fluent-ffmpeg';
import * as ffmpegPath from '@ffmpeg-installer/ffmpeg';
import * as path from 'path';
import * as os from 'os';
import * as fs from 'fs';
import fetch from 'node-fetch';
import { defineSecret } from 'firebase-functions/params';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { createReadStream } from 'fs';

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

// Define OpenAI API key secret
const openaiApiKey = defineSecret('OPENAI_API_KEY');

// Set ffmpeg path
ffmpeg.setFfmpegPath(ffmpegPath.path);

// Helper function to get OpenAI client
function getOpenAIClient() {
  return new OpenAI({ apiKey: openaiApiKey.value() });
}

interface TranscriptSegment {
  text: string;
  start: number;
  end: number;
  words: Array<{
    word: string;
    start: number;
    end: number;
  }>;
  keywords: string[];
}

interface TranscriptResult {
  segments: TranscriptSegment[];
  text: string;
}

interface GenerateTranscriptRequest {
  videoId: string;
  videoUrl: string;
}

interface WhisperWord {
  word: string;
  start: number;
  end: number;
}

interface WhisperSegment {
  text: string;
  start: number;
  end: number;
  words: WhisperWord[];
}

interface WhisperResponse {
  text: string;
  segments: WhisperSegment[];
}

// Internal function for generating transcripts
async function generateTranscriptInternal(videoId: string, videoUrl: string): Promise<TranscriptResult> {
  const tempDir = path.join(os.tmpdir(), videoId);
  const audioPath = path.join(tempDir, 'audio.mp3');
  
  try {
    // Initialize OpenAI client
    const openai = getOpenAIClient();
    
    // Download video
    console.info('📥 Downloading video file...');
    const tempVideoPath = path.join(tempDir, 'video.mp4');
    await fs.promises.mkdir(tempDir, { recursive: true });
    
    const response = await fetch(videoUrl);
    if (!response.ok) {
      throw new Error(`Failed to download video: ${response.statusText}`);
    }
    
    const fileStream = fs.createWriteStream(tempVideoPath);
    await new Promise((resolve, reject) => {
      response.body?.pipe(fileStream);
      fileStream.on('finish', resolve);
      fileStream.on('error', reject);
    });
    
    // Extract audio
    console.info('🔊 Extracting audio from video...');
    await new Promise((resolve, reject) => {
      ffmpeg(tempVideoPath)
        .toFormat('mp3')
        .on('end', resolve)
        .on('error', reject)
        .save(audioPath);
    });
    
    // Transcribe audio
    console.info('🎙️ Transcribing audio...');
    const transcriptionResponse = await openai.audio.transcriptions.create({
      file: createReadStream(audioPath),
      model: 'whisper-1',
      response_format: 'verbose_json',
      timestamp_granularities: ['word', 'segment'],
      language: 'en'
    });

    // Debug log the raw response structure
    console.info('📝 OpenAI Response Structure:', {
      hasText: !!transcriptionResponse.text,
      hasSegments: Array.isArray(transcriptionResponse.segments),
      segmentCount: transcriptionResponse.segments?.length,
      responseKeys: Object.keys(transcriptionResponse),
    });

    // Log full response for debugging
    console.info('📝 Full OpenAI response:', JSON.stringify(transcriptionResponse, null, 2));

    // Safely cast and extract the response
    const transcript = transcriptionResponse as unknown as WhisperResponse;
    
    // Validate response structure
    if (!transcript.text) {
      console.error('❌ Missing text in OpenAI response');
      throw new Error('Invalid OpenAI response: missing text');
    }

    if (!transcript.segments || transcript.segments.length === 0) {
      console.warn('⚠️ No segments found in transcript response');
      console.info('📝 Creating segments from text:', transcript.text);
      // Create segments from the full text by splitting on periods
      const sentences = transcript.text.split(/[.!?]+/).filter(s => s.trim().length > 0);
      console.info(`📝 Created ${sentences.length} segments from text`);
      const segments: TranscriptSegment[] = sentences.map((sentence, index) => {
        const segment = {
          start: index * 1000, // Rough estimate, 1 second per sentence
          end: (index + 1) * 1000,
          text: sentence.trim() + '.',
          words: [], // No word-level timing available
          keywords: [],
        };
        console.info(`📝 Created segment ${index + 1}:`, segment);
        return segment;
      });
      return { segments, text: transcript.text };
    }

    // Process segments with additional logging
    console.info('✨ Processing transcript segments...');
    console.info(`Found ${transcript.segments.length} segments in OpenAI response`);
    
    const segments: TranscriptSegment[] = transcript.segments.map((segment, index) => {
      console.info(`\n📝 Processing segment ${index + 1}/${transcript.segments.length}`);
      console.info(`Segment details:`, {
        text: segment.text,
        start: segment.start,
        end: segment.end,
        wordCount: segment.words?.length ?? 0
      });
      
      // If segment has no words but has text, create word timings
      const words = segment.words?.length ? segment.words : segment.text.split(' ').map((word, i, arr) => {
        const wordDuration = (segment.end - segment.start) / arr.length;
        const wordStart = segment.start + (i * wordDuration);
        return {
          word,
          start: wordStart,
          end: wordStart + wordDuration
        };
      });

      console.info(`Words in segment:`, words.length);
      
      const processedSegment = {
        start: Math.round(segment.start * 1000),
        end: Math.round(segment.end * 1000),
        text: segment.text,
        words: words.map(word => ({
          word: word.word,
          start: Math.round(word.start * 1000),
          end: Math.round(word.end * 1000),
        })),
        keywords: [], // TODO: Implement keyword extraction
      };

      console.info(`Processed segment timing:`, {
        start: processedSegment.start,
        end: processedSegment.end,
        duration: processedSegment.end - processedSegment.start,
        wordCount: processedSegment.words.length
      });

      return processedSegment;
    });

    // Validate processed segments
    console.info('\n✨ Validating processed segments...');
    console.info(`Total segments: ${segments.length}`);
    console.info(`Total words: ${segments.reduce((sum, seg) => sum + seg.words.length, 0)}`);
    console.info(`Average segment duration: ${segments.reduce((sum, seg) => sum + (seg.end - seg.start), 0) / segments.length}ms`);

    // Log first and last segment for verification
    if (segments.length > 0) {
      console.info('\n📝 First segment:', JSON.stringify(segments[0], null, 2));
      console.info('📝 Last segment:', JSON.stringify(segments[segments.length - 1], null, 2));
    }

    // Clean up temp files
    console.info('🧹 Cleaning up temporary files...');
    await fs.promises.rm(tempDir, { recursive: true, force: true });
    
    // Return result
    const result: TranscriptResult = {
      segments,
      text: transcript.text,
    };

    console.info('\n✅ Final transcript statistics:', {
      totalSegments: result.segments.length,
      totalWords: result.segments.reduce((sum, seg) => sum + seg.words.length, 0),
      textLength: result.text.length,
      averageSegmentLength: Math.round(result.text.length / result.segments.length)
    });
    
    return result;
    
  } catch (error) {
    // Clean up temp files on error
    try {
      await fs.promises.rm(tempDir, { recursive: true, force: true });
    } catch (cleanupError) {
      console.warn('⚠️ Failed to clean up temporary files:', cleanupError);
    }
    
    throw error;
  }
}

// Firestore trigger for video status changes
export const generateTranscriptOnStatusChange = onDocumentUpdated({
  document: 'videos/{videoId}',
  secrets: [openaiApiKey]
}, async (event) => {
  const beforeData = event.data?.before?.data();
  const afterData = event.data?.after?.data();
  const videoId = event.params.videoId;

  // Check if this is a status change from uploading to active
  if (beforeData?.status !== 'uploading' || afterData?.status !== 'active') {
    console.info('⏭️ TRANSCRIPT TRIGGER - Skipping: Not a status change from uploading to active', {
      beforeStatus: beforeData?.status,
      afterStatus: afterData?.status
    });
    return;
  }

  // Verify video URL is available
  if (!afterData?.videoUrl) {
    console.error('❌ TRANSCRIPT TRIGGER - Error: No video URL available after status change to active');
    return;
  }

  // Validate video URL format
  if (!afterData.videoUrl.startsWith('https://firebasestorage.googleapis.com/') && 
      !afterData.videoUrl.startsWith('https://storage.googleapis.com/') &&
      !afterData.videoUrl.startsWith('gs://')) {
    console.error('❌ TRANSCRIPT TRIGGER - Error: Invalid video URL format:', afterData.videoUrl);
    return;
  }

  console.info('🎯 TRANSCRIPT TRIGGER: Starting transcript process for video:', {
    videoId,
    videoUrl: afterData.videoUrl
  });

  try {
    // Check if transcript already exists and is processing
    const existingTranscript = await db.collection('transcripts').doc(videoId).get();
    if (existingTranscript.exists) {
      const data = existingTranscript.data();
      if (data?.isProcessing) {
        console.info('⏭️ TRANSCRIPT TRIGGER: Transcript already processing for video:', videoId);
        return;
      }
    }

    // Mark as processing in Firestore
    console.info('⏳ TRANSCRIPT TRIGGER: Marking transcript as processing:', videoId);
    await db.collection('transcripts').doc(videoId).set({
      isProcessing: true,
      metadata: {
        lastAccessed: admin.firestore.FieldValue.serverTimestamp(),
        version: 1,
        startedProcessing: admin.firestore.FieldValue.serverTimestamp(),
      },
    }, { merge: true });

    // Get download URL if needed (if URL is gs:// format)
    let downloadUrl = afterData.videoUrl;
    if (downloadUrl.startsWith('gs://')) {
      console.info('🔗 TRANSCRIPT TRIGGER: Converting gs:// URL to signed URL');
      const bucketName = downloadUrl.split('/')[2];
      const filePath = downloadUrl.split('/').slice(3).join('/');
      const bucket = admin.storage().bucket(bucketName);
      const file = bucket.file(filePath);
      const [signedUrl] = await file.getSignedUrl({
        action: 'read',
        expires: Date.now() + 3600000, // 1 hour
      });
      downloadUrl = signedUrl;
      console.info('✅ TRANSCRIPT TRIGGER: Generated signed URL successfully');
    }

    // Call the transcription function
    console.info('🚀 TRANSCRIPT TRIGGER: Initiating transcription');
    const result = await generateTranscriptInternal(videoId, downloadUrl);
    console.info('✨ TRANSCRIPT TRIGGER: Transcription completed successfully:', result);

    // Save the transcript result to Firestore
    console.info('💾 Preparing Firestore document...');
    const firestoreDoc = {
      segments: result.segments.map(segment => ({
        start: segment.start,
        end: segment.end,
        text: segment.text,
        words: segment.words.map(word => ({
          word: word.word,
          start: word.start,
          end: word.end,
        })),
        keywords: [],
      })),
      metadata: {
        language: 'en',
        lastAccessed: admin.firestore.FieldValue.serverTimestamp(),
        version: 1,
        startedProcessing: null,
        errorTimestamp: null,
      },
      isProcessing: false,
      error: null,
    };

    console.info('📝 Firestore document structure:', {
      segmentCount: firestoreDoc.segments.length,
      totalWords: firestoreDoc.segments.reduce((sum, seg) => sum + seg.words.length, 0),
      metadata: firestoreDoc.metadata,
    });

    // Validate document before saving
    if (!firestoreDoc.segments || !Array.isArray(firestoreDoc.segments)) {
      throw new Error('Invalid document structure: segments must be an array');
    }

    for (const [index, segment] of firestoreDoc.segments.entries()) {
      if (!segment.text || typeof segment.start !== 'number' || typeof segment.end !== 'number') {
        console.error('❌ Invalid segment structure:', { index, segment });
        throw new Error(`Invalid segment at index ${index}`);
      }
    }

    console.info('💾 Saving validated document to Firestore...');
    await db.collection('transcripts').doc(videoId).set(firestoreDoc);
    console.info('✅ Firestore save completed successfully');

  } catch (error) {
    console.error('❌ TRANSCRIPT TRIGGER: Error during transcription process:', {
      error: error instanceof Error ? error.message : 'Unknown error',
      videoId,
      stack: error instanceof Error ? error.stack : undefined,
    });
    
    await db.collection('transcripts').doc(videoId).set({
      error: error instanceof Error ? error.message : 'Unknown error occurred',
      isProcessing: false,
      metadata: {
        lastAccessed: admin.firestore.FieldValue.serverTimestamp(),
        errorTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      },
    }, { merge: true });
  }
});

// Manual transcription generation endpoint
export const generateTranscript = onCall({
  memory: '2GiB',
  timeoutSeconds: 540,
  maxInstances: 10,
  region: 'us-central1',
  secrets: [openaiApiKey]
}, async (request) => {
  console.info('🎯 Manual transcript generation requested');

  const data = request.data;
  
  // Type check and validate the request data
  if (!data || typeof data !== 'object') {
    console.error('❌ Invalid request data format');
    throw new HttpsError(
      'invalid-argument',
      'Request data must be an object'
    );
  }

  const transcriptRequest = data as GenerateTranscriptRequest;
  
  if (!transcriptRequest.videoId || !transcriptRequest.videoUrl) {
    console.error('❌ Missing required fields in request');
    throw new HttpsError(
      'invalid-argument',
      'Video ID and URL are required'
    );
  }

  try {
    console.info('🎬 Starting manual transcription for video:', transcriptRequest.videoId);
    
    // Mark as processing in Firestore
    console.info('⏳ Marking transcript as processing');
    await db.collection('transcripts').doc(transcriptRequest.videoId).set({
      isProcessing: true,
      metadata: {
        lastAccessed: admin.firestore.FieldValue.serverTimestamp(),
        version: 1,
        startedProcessing: admin.firestore.FieldValue.serverTimestamp(),
      },
    });

    // Generate transcript
    const result = await generateTranscriptInternal(transcriptRequest.videoId, transcriptRequest.videoUrl);
    console.info('✨ Transcription completed successfully');

    // Save to Firestore
    console.info('💾 Preparing Firestore document...');
    const firestoreDoc = {
      segments: result.segments.map(segment => ({
        start: segment.start,
        end: segment.end,
        text: segment.text,
        words: segment.words.map(word => ({
          word: word.word,
          start: word.start,
          end: word.end,
        })),
        keywords: [],
      })),
      metadata: {
        language: 'en',
        lastAccessed: admin.firestore.FieldValue.serverTimestamp(),
        version: 1,
        startedProcessing: null,
        errorTimestamp: null,
      },
      isProcessing: false,
      error: null,
    };

    console.info('📝 Firestore document structure:', {
      segmentCount: firestoreDoc.segments.length,
      totalWords: firestoreDoc.segments.reduce((sum, seg) => sum + seg.words.length, 0),
      metadata: firestoreDoc.metadata,
    });

    // Validate document before saving
    if (!firestoreDoc.segments || !Array.isArray(firestoreDoc.segments)) {
      throw new Error('Invalid document structure: segments must be an array');
    }

    for (const [index, segment] of firestoreDoc.segments.entries()) {
      if (!segment.text || typeof segment.start !== 'number' || typeof segment.end !== 'number') {
        console.error('❌ Invalid segment structure:', { index, segment });
        throw new Error(`Invalid segment at index ${index}`);
      }
    }

    console.info('💾 Saving validated document to Firestore...');
    await db.collection('transcripts').doc(transcriptRequest.videoId).set(firestoreDoc);
    console.info('✅ Firestore save completed successfully');

    return result;
  } catch (error) {
    console.error('❌ Manual transcription failed:', error);
    
    // Update Firestore with error
    await db.collection('transcripts').doc(transcriptRequest.videoId).set({
      error: error instanceof Error ? error.message : 'Unknown error occurred',
      isProcessing: false,
      metadata: {
        lastAccessed: admin.firestore.FieldValue.serverTimestamp(),
        errorTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      },
    }, { merge: true });
    
    throw new HttpsError(
      'internal',
      'Failed to generate transcript',
      { videoId: transcriptRequest.videoId }
    );
  }
});

// Simple function to test if the API key is valid
export const testOpenAIKey = onCall({
  secrets: [openaiApiKey]
}, async (request) => {
  try {
    console.info("🔑 Testing OpenAI API key...");
    const openai = new OpenAI({
      apiKey: openaiApiKey.value(),
    });
    
    const models = await openai.models.list();
    return {
      success: true,
      message: "API key is valid",
      models: models.data.length
    };
  } catch (error) {
    console.error("❌ API key test failed:", error);
    if (error instanceof Error) {
      throw new Error(`Invalid API key or API error: ${error.message}`);
    }
    throw new Error("Failed to validate API key");
  }
}); 