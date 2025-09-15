---
description: Create a new GitHub issue (bug or feature request)
argument-hint: [description]
---

# Issue Create Command

## Parameters
- `description`: Brief description of the issue (bug or small feature)

## Behavior

1. **Create GitHub Issue**
   - Creates a new issue directly in the GitHub repository
   - Uses GitHub's native issue system for tracking
   - Automatically applies appropriate labels based on content

2. **Issue Classification**
   - Analyzes description to determine if it's a bug or feature request
   - Applies `bug` label for bugs and defects
   - Applies `feature` label for new features and enhancements
   - Applies `improvement` label for optimization requests

3. **Rich Issue Content**
   - Creates comprehensive issue description with problem statement
   - Includes sections for current behavior, expected behavior, and steps to reproduce
   - Provides implementation guidance and acceptance criteria
   - Links to relevant files when applicable

## GitHub Issue Content

The created GitHub issue will include:

### Comprehensive Description
- **Problem Statement**: Clear description of the issue or enhancement
- **Current Behavior**: What currently happens (for bugs)
- **Expected Behavior**: What should happen instead
- **Steps to Reproduce**: How to reproduce the issue (for bugs)
- **Implementation Guidance**: Technical notes and approach suggestions
- **Acceptance Criteria**: Specific conditions for completion

### Automatic Labels
- **bug**: For defects, errors, or incorrect behavior
- **feature**: For new functionality requests
- **improvement**: For enhancements to existing features

### Rich Formatting
- Code examples using GDScript syntax highlighting
- Structured sections for easy reading and understanding
- Links to relevant files in the repository
- Professional issue formatting following GitHub best practices

## Example Usage
```
issue:create "Fix incorrect indentation after match expressions"
```

This creates:
- A new GitHub Issue in the repository
- Appropriate labels based on the description
- Comprehensive issue content with problem statement and implementation guidance
- Direct integration with GitHub's issue tracking system

## Benefits
- **Native GitHub Integration**: Issues tracked in GitHub's native system
- **Team Collaboration**: Multiple contributors can comment and collaborate
- **Issue Linking**: Can link to pull requests, commits, and other issues
- **Automated Workflows**: GitHub Actions can trigger on issue events
- **Single Source of Truth**: All project tracking in one place
