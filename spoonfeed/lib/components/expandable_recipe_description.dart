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
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.5,
                color: Theme.of(context).primaryColor,
              ),
              h2: widget.textStyle?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 2.0,
                color: Theme.of(context).primaryColor,
              ),
              listBullet: widget.textStyle?.copyWith(
                color: Theme.of(context).primaryColor,
              ),
              listIndent: 24.0,
              blockSpacing: 24.0,
              textAlign: WrapAlignment.start,
              listBulletPadding: const EdgeInsets.only(right: 12),
              textScaleFactor: 1.0,
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
              ),
            ),
            selectable: true,
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