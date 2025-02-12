/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import { onCall } from "firebase-functions/v2/https";
import OpenAI from "openai";
import * as fs from "fs";

// Initialize OpenAI with the API key from environment variables
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export const transcribeAudio = onCall(async (request) => {
  try {
    const audioPath = request.data.audioPath;
    if (!audioPath) {
      throw new Error("Audio path is required");
    }

    // Read the audio file
    const audioBuffer = await fs.promises.readFile(audioPath);

    // Create a form data object for the API request
    const formData = new FormData();
    formData.append("file", new Blob([audioBuffer], { type: "audio/mp3" }), "audio.mp3");
    formData.append("model", "whisper-1");
    formData.append("response_format", "verbose_json");

    // Call OpenAI API to transcribe the audio
    const response = await openai.audio.transcriptions.create({
      file: audioPath,
      model: "whisper-1",
      response_format: "verbose_json"
    });

    return {
      success: true,
      transcript: response
    };
  } catch (error) {
    console.error("Error in transcribeAudio:", error);
    if (error instanceof Error) {
      throw new Error(`Failed to transcribe audio: ${error.message}`);
    }
    throw new Error("Failed to transcribe audio: Unknown error");
  }
});
