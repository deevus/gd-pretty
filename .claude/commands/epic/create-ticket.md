---
description: Creates a new ticket within an existing epic
argument-hint: [epic-name] [description]
---

## Parameters
- `epic-name`: Name of the existing epic (must exist in `work/epics/`)
- `description`: Brief description of the ticket/story/task

## Behavior

1. **Validate Epic Exists**
   - Check that `work/epics/{epic-name}/` directory exists
   - If not found, show error and list available epics

2. **Generate Ticket Number**
   - Auto-increment ticket numbers (001, 002, 003, etc.)
   - Check existing tickets in `work/epics/{epic-name}/tickets/`

3. **Create Ticket File**
   - Creates `work/epics/{epic-name}/tickets/{number}-{ticket-name}.md`
   - Uses kebab-case for ticket name derived from description
   - Follows Agile user story/task template

4. **Update Epic Description**
   - Adds ticket reference to epic's breakdown section
   - Maintains epic-level tracking and progress

## Ticket Types & Templates

### User Story Template
For user-facing functionality:
- **Story**: As a [user type], I want [functionality] so that [benefit]
- **Acceptance Criteria**: Given/When/Then scenarios
- **Definition of Done**: Specific completion requirements

### Technical Task Template
For implementation work:
- **Task**: [Technical objective and scope]
- **Implementation Notes**: Technical approach and considerations
- **Acceptance Criteria**: Technical completion requirements

### Bug/Defect Template
For fixes and improvements:
- **Issue**: Description of problem or improvement
- **Expected Behavior**: What should happen
- **Current Behavior**: What currently happens
- **Resolution Criteria**: How to know it's fixed

## Ticket Structure

Each ticket will include:

### Metadata
- Ticket number and title
- Epic reference and relationship
- Story type (User Story, Technical Task, Bug, etc.)
- Priority and effort estimation
- Dependencies and blockers

### Content
- **Summary**: Clear, concise objective
- **Description**: Detailed explanation of work needed
- **Acceptance Criteria**: Specific, testable conditions for completion
- **Implementation Notes**: Technical approach and considerations
- **Testing Requirements**: How to validate completion
- **Definition of Done**: Final completion checklist

### Tracking
- Status tracking (Not Started, In Progress, Completed)
- Progress checkboxes for sub-tasks
- Dependencies and blockers
- Implementation notes and decisions

## Example Usage
```
epic:create-ticket comment-processing "Implement inline comment detection and positioning"
```

This creates:
- `work/epics/comment-processing/tickets/001-implement-inline-comment-detection.md`
- Updates `work/epics/comment-processing/description.md` with ticket reference
- Structured ticket documentation following Agile user story format

## Integration with Epic
- Tickets automatically link back to parent epic
- Epic description updated with ticket references
- Progress tracking rolls up to epic level
- Dependency management across epic scope
