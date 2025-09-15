---
description: Create a new epic
argument-hint: [name] [description]
---

# Epic Create Command

## Parameters
- `name`: Epic name (kebab-case, used for directory naming)
- `description`: Brief description of what the epic aims to achieve

## Behavior

1. **Create Epic Directory Structure**
   ```
   work/epics/{epic-name}/
   ├── description.md
   └── tickets/
   ```

2. **Generate Epic Description**
   - Creates `work/epics/{epic-name}/description.md`
   - Follows Agile epic template with user stories, acceptance criteria, and success metrics
   - Includes proper epic metadata and tracking information

3. **Post-Creation Prompt**
   - After creating the epic, Claude will ask: "Would you like to create a ticket for this epic?"
   - If yes, guide user to use `epic:create-ticket` command

## Epic Description Template

The generated `description.md` will include:

### Epic Structure
- **Epic Name & Overview**
- **Business Value & Objectives**
- **User Stories** (As a... I want... So that...)
- **Acceptance Criteria** (high-level success conditions)
- **Success Metrics** (measurable outcomes)
- **Dependencies & Assumptions**
- **Epic Breakdown** (planned tickets/tasks)
- **Timeline & Effort Estimation**
- **Definition of Done**

### Agile Best Practices
- User-centric language and value focus
- Measurable success criteria
- Clear scope boundaries
- Iterative delivery planning
- Risk and dependency identification

## Example Usage
```
epic:create comment-processing "Add comprehensive comment support to GDScript formatter"
```

This creates:
- `work/epics/comment-processing/description.md`
- `work/epics/comment-processing/tickets/` directory
- Structured epic documentation following Agile standards
