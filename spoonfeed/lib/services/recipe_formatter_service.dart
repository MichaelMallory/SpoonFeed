import 'package:cloud_functions/cloud_functions.dart';

class RecipeFormatterService {
  static const String _recipeTemplate = '''
# {title}

## Ingredients
{ingredients}

## Instructions
{steps}

---
*This recipe was automatically generated from the video content*
''';

  /// Formats a recipe into a clean markdown string
  static String formatRecipe(Map<String, dynamic> recipe) {
    final ingredients = (recipe['ingredients'] as List<String>)
        .map((ingredient) => '- $ingredient')
        .join('\n');
    
    final steps = (recipe['steps'] as List<String>)
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');

    return _recipeTemplate
        .replaceAll('{title}', recipe['title'])
        .replaceAll('{ingredients}', ingredients)
        .replaceAll('{steps}', steps);
  }

  /// Calls the Cloud Function to generate a recipe from transcript
  static Future<String> generateRecipeFromTranscript(String videoId) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateRecipeFromTranscript')
          .call({'videoId': videoId});
      
      if (result.data['error'] != null) {
        throw Exception(result.data['error']);
      }

      return formatRecipe(result.data['recipe']);
    } catch (e) {
      throw Exception('Failed to generate recipe: $e');
    }
  }
} 