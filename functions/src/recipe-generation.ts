import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { defineSecret } from 'firebase-functions/params';

// Use the existing OpenAI API key secret
const openaiApiKey = defineSecret('OPENAI_API_KEY');

interface Recipe {
  title: string;
  ingredients: string[];
  steps: string[];
}

// Function to generate recipe from transcript
export async function generateRecipeFromTranscriptInternal(videoId: string): Promise<Recipe> {
  try {
    console.info('🔄 [Recipe Generation] Starting recipe generation for video:', videoId);
    
    const openai = new OpenAI({
      apiKey: openaiApiKey.value(),
    });

    // Get the video transcript
    console.info('📝 [Recipe Generation] Fetching transcript document:', videoId);
    const transcriptDoc = await admin.firestore()
      .collection('transcripts')
      .doc(videoId)
      .get();

    if (!transcriptDoc.exists) {
      console.error('❌ [Recipe Generation] Transcript not found for video:', videoId);
      throw new Error('Transcript not found');
    }

    const transcript = transcriptDoc.data();
    if (!transcript || transcript.isProcessing || transcript.error) {
      console.error('❌ [Recipe Generation] Transcript not ready or has error:', {
        videoId,
        isProcessing: transcript?.isProcessing,
        error: transcript?.error
      });
      throw new Error('Transcript not ready or has error');
    }

    // Combine all segments into one text
    console.info('📝 [Recipe Generation] Processing transcript segments:', {
      videoId,
      segmentCount: transcript.segments.length,
      firstSegment: transcript.segments[0]?.text,
      lastSegment: transcript.segments[transcript.segments.length - 1]?.text
    });
    const fullText = transcript.segments
      .map((segment: any) => segment.text)
      .join(' ');

    console.info('🤖 [Recipe Generation] Sending to OpenAI:', {
      videoId,
      textLength: fullText.length,
      firstWords: fullText.slice(0, 100) + '...'
    });

    // Generate recipe using OpenAI
    const completion = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [
        {
          role: "system",
          content: "You are a professional chef who creates clear, concise recipes. Convert the following cooking video transcript into a well-structured recipe. Format the output as clean text with a title, ingredients list, and step-by-step instructions. Do not include markdown syntax characters (like #) in the actual content - they will be added during formatting. Focus only on the recipe-relevant information."
        },
        {
          role: "user",
          content: fullText
        }
      ],
      temperature: 0.7,
      max_tokens: 1000,
    });

    const recipeText = completion.choices[0]?.message?.content;
    if (!recipeText) {
      console.error('❌ [Recipe Generation] No recipe text generated:', { videoId });
      throw new Error('Failed to generate recipe');
    }

    console.info('📝 [Recipe Generation] Raw recipe text:', {
      videoId,
      recipeText
    });

    // Parse the generated recipe text into structured format
    console.info('🔄 [Recipe Generation] Parsing recipe text into structured format');
    const recipe = parseRecipeText(recipeText);
    
    console.info('✅ [Recipe Generation] Recipe parsed successfully:', {
      videoId,
      title: recipe.title,
      ingredientCount: recipe.ingredients.length,
      ingredients: recipe.ingredients,
      stepCount: recipe.steps.length,
      steps: recipe.steps
    });

    return recipe;
  } catch (error) {
    console.error('❌ [Recipe Generation] Error generating recipe:', {
      videoId,
      error: error instanceof Error ? error.message : 'Unknown error',
      stack: error instanceof Error ? error.stack : undefined
    });
    throw error;
  }
}

// Function to format recipe as markdown string
export function formatRecipeAsMarkdown(recipe: Recipe): string {
  const markdown = `# ${recipe.title.replace(/^#*\s*/, '')}

## Ingredients

${recipe.ingredients.map(i => `- ${i.replace(/^[-#*]\s*/, '')}`).join('\n')}

## Instructions

${recipe.steps.map((s, i) => `${i + 1}. ${s.replace(/^[-#*\d.]\s*/, '')}\n`).join('\n')}

---
*This recipe was automatically generated from the video content*`;

  console.info('📝 [Recipe Generation] Formatted recipe as markdown:', {
    title: recipe.title,
    markdownLength: markdown.length,
    preview: markdown.slice(0, 200) + '...'
  });

  return markdown;
}

// Callable function for manual recipe generation
export const generateRecipeFromTranscript = functions.https.onCall({
  secrets: [openaiApiKey]
}, async (request: functions.https.CallableRequest) => {
  try {
    const videoId = request.data?.videoId;
    if (!videoId || typeof videoId !== 'string') {
      throw new Error('Video ID is required');
    }

    const recipe = await generateRecipeFromTranscriptInternal(videoId);
    const formattedRecipe = formatRecipeAsMarkdown(recipe);

    // Update the video document with the recipe
    const videoRef = admin.firestore().collection('videos').doc(videoId);
    await videoRef.update({
      description: formattedRecipe,
      hasRecipe: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { recipe };
  } catch (error: unknown) {
    console.info('Recipe generation error:', error);
    return { error: error instanceof Error ? error.message : 'Unknown error occurred' };
  }
});

// Trigger to automatically generate recipe when transcript is completed
export const onTranscriptComplete = onDocumentUpdated({
  document: 'transcripts/{transcriptId}',
  secrets: [openaiApiKey],
  region: 'us-central1'
}, async (event) => {
  const beforeData = event.data?.before?.data();
  const afterData = event.data?.after?.data();
  const transcriptId = event.params.transcriptId;

  console.info(`[Recipe Generation] 🔄 Transcript update detected for ${transcriptId}:`, {
    beforeProcessing: beforeData?.isProcessing,
    afterProcessing: afterData?.isProcessing,
    beforeSegments: beforeData?.segments?.length,
    afterSegments: afterData?.segments?.length,
    hasError: afterData?.error,
  });

  // Check if this is a completed transcript
  if (!afterData || afterData.isProcessing || afterData.error || !afterData.segments?.length) {
    console.info(`[Recipe Generation] ⏭️ Skipping recipe generation: Transcript not ready`, {
      isProcessing: afterData?.isProcessing,
      hasError: afterData?.error,
      segmentCount: afterData?.segments?.length
    });
    return;
  }

  // Check if recipe already exists
  const videoDoc = await admin.firestore().collection('videos').doc(transcriptId).get();
  if (!videoDoc.exists) {
    console.info(`[Recipe Generation] ⏭️ Skipping recipe generation: Video document not found for ${transcriptId}`);
    return;
  }

  const videoData = videoDoc.data();
  if (videoData?.hasRecipe) {
    console.info(`[Recipe Generation] ⏭️ Skipping recipe generation: Recipe already exists for ${transcriptId}`);
    return;
  }

  console.info('🎯 [Recipe Generation] Starting recipe generation from transcript update:', {
    transcriptId,
    segmentCount: afterData.segments.length
  });

  try {
    const recipe = await generateRecipeFromTranscriptInternal(transcriptId);
    const formattedRecipe = formatRecipeAsMarkdown(recipe);

    console.info('💾 [Recipe Generation] Saving recipe to video document:', {
      transcriptId,
      title: recipe.title,
      description: formattedRecipe.slice(0, 100) + '...'
    });

    // Get the video document first to verify it exists
    const videoRef = admin.firestore().collection('videos').doc(transcriptId);
    const videoDoc = await videoRef.get();
    
    if (!videoDoc.exists) {
      throw new Error('Video document not found when trying to save recipe');
    }

    // Update with recipe
    await videoRef.update({
      description: formattedRecipe,
      hasRecipe: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.info('✅ [Recipe Generation] Successfully saved recipe to video:', {
      transcriptId,
      videoExists: videoDoc.exists,
      recipeLength: formattedRecipe.length
    });

    // Verify the update
    const updatedDoc = await videoRef.get();
    const updatedData = updatedDoc.data();
    
    console.info('✅ [Recipe Generation] Verified recipe save:', {
      transcriptId,
      hasRecipe: updatedData?.hasRecipe,
      descriptionLength: updatedData?.description?.length,
      descriptionPreview: updatedData?.description?.slice(0, 100) + '...'
    });

  } catch (error) {
    console.error('❌ [Recipe Generation] Failed to generate or save recipe:', {
      transcriptId,
      error: error instanceof Error ? error.message : 'Unknown error',
      stack: error instanceof Error ? error.stack : undefined
    });
    
    // Log the transcript data for debugging
    console.info(`[Recipe Generation] 📝 Transcript data:`, {
      transcriptId,
      segmentCount: afterData.segments.length,
      totalText: afterData.segments.reduce((acc: number, segment: { text: string }) => acc + segment.text.length, 0),
      error: error instanceof Error ? error.message : 'Unknown error',
      stack: error instanceof Error ? error.stack : undefined,
    });

    // Create an error document to track failures
    try {
      await admin.firestore().collection('errors').add({
        type: 'recipe_generation_failure',
        videoId: transcriptId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        error: error instanceof Error ? error.message : 'Unknown error',
        stack: error instanceof Error ? error.stack : undefined,
        transcriptData: {
          segmentCount: afterData.segments.length,
          totalText: afterData.segments.reduce((acc: number, segment: { text: string }) => acc + segment.text.length, 0)
        }
      });
      console.info(`[Recipe Generation] 📝 Error logged to Firestore for ${transcriptId}`);
    } catch (logError) {
      console.info(`[Recipe Generation] ❌ Failed to log error to Firestore:`, logError);
    }
  }
});

// Function to parse recipe text into structured format
export function parseRecipeText(text: string): Recipe {
  // Split the text into sections
  const sections = text.split('\n\n');
  
  // Extract title (first line), remove any "Title:" prefix
  const title = sections[0].replace(/^#*\s*(?:Title:\s*)?/, '').trim();
  
  // Find ingredients section
  const ingredientsSection = sections.find(s => s.toLowerCase().includes('ingredients'))
    ?.split('\n')
    .slice(1) // Skip the "Ingredients" header
    .map(i => i.replace(/^[-*]\s*/, '').trim()) // Remove bullet points and whitespace
    .filter(i => i.length > 0) || [];
  
  // Find instructions/steps section (try multiple possible headers)
  const stepsSection = sections.find(s => 
    s.toLowerCase().includes('instructions') || 
    s.toLowerCase().includes('steps') ||
    s.toLowerCase().includes('directions') ||
    s.toLowerCase().includes('method')
  )
    ?.split('\n')
    .slice(1) // Skip the header
    .map(s => s.replace(/^\d+\.\s*/, '').trim()) // Remove step numbers
    .filter(s => s.length > 0) || [];
  
  // If no steps found in a section, try to find numbered lines in any section
  const numberedSteps = stepsSection.length === 0 ? 
    sections.flatMap(section => 
      section.split('\n')
        .filter(line => /^\d+\.\s/.test(line))
        .map(s => s.replace(/^\d+\.\s*/, '').trim())
    ) : [];
  
  return {
    title,
    ingredients: ingredientsSection,
    steps: stepsSection.length > 0 ? stepsSection : numberedSteps,
  };
} 