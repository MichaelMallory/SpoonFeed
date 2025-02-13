import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ExpandableRecipeDescription extends StatefulWidget {
  final String description;
  final double collapsedHeight;
  final TextStyle? textStyle;

  const ExpandableRecipeDescription({
    Key? key,
    required this.description,
    this.collapsedHeight = 100.0,
    this.textStyle,
  }) : super(key: key);

  @override
  State<ExpandableRecipeDescription> createState() => _ExpandableRecipeDescriptionState();
}

class _ExpandableRecipeDescriptionState extends State<ExpandableRecipeDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: _isExpanded ? double.infinity : widget.collapsedHeight,
          ),
          child: Markdown(
            data: widget.description,
            shrinkWrap: true,
            styleSheet: MarkdownStyleSheet(
              p: widget.textStyle,
              h1: widget.textStyle?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              h2: widget.textStyle?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              listBullet: widget.textStyle,
            ),
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isExpanded ? 'Show Less' : 'Show More',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              Icon(
                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
} 