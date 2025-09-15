---
description: Create a new standalone issue (bug or small feature)
argument-hint: [description]
---

# Issue Create Command

## Parameters
- `description`: Brief description of the issue (bug or small feature)

## Behavior

1. **Create Issue Directory Structure**
   ```
   work/issues/{issue-number}-{issue-name}/
   ├── description.md
   ```

2. **Generate Issue Number**
   - Auto-increment issue numbers (001, 002, 003, etc.)
   - Check existing issues in `work/issues/`
   - Use 3-digit zero-padded format

3. **Generate Issue Description**
   - Creates `work/issues/{issue-number}-{issue-name}/description.md`
   - Follows Agile issue template with clear problem statement and acceptance criteria
   - Includes proper issue metadata and tracking information

## Issue Description Template

The generated `description.md` will include:

### Issue Structure
- **Issue Number & Title**
- **Issue Type** (Bug, Small Feature, Improvement)
- **Problem Statement** (What needs to be addressed)
- **Current Behavior** (For bugs: what currently happens)
- **Expected Behavior** (What should happen)
- **Acceptance Criteria** (Specific, testable conditions)
- **Implementation Notes** (Technical approach and considerations)
- **Testing Requirements** (How to validate completion)
- **Definition of Done** (Completion checklist)

### Issue Types

#### Bug Template
- **Problem**: Description of the bug or defect
- **Current Behavior**: What currently happens (with examples)
- **Expected Behavior**: What should happen
- **Steps to Reproduce**: If applicable
- **Resolution Criteria**: How to know it's fixed

#### Small Feature Template
- **Feature**: Description of the small feature or enhancement
- **User Value**: Why this feature is needed
- **Acceptance Criteria**: Specific functionality requirements
- **Implementation Scope**: Boundaries and limitations

#### Improvement Template
- **Improvement**: Description of the enhancement
- **Current State**: What exists now
- **Desired State**: What should be improved
- **Success Metrics**: How to measure improvement

## Issue Structure

Each issue will include:

### Metadata
- Issue number and title
- Issue type (Bug, Small Feature, Improvement)
- Priority level (High, Medium, Low)
- Effort estimation (Small, Medium, Large)
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
- Implementation notes and decisions
- Resolution summary upon completion

## Example Usage
```
issue:create "Fix incorrect indentation after match expressions"
```

This creates:
- `work/issues/001-fix-incorrect-indentation-after-match-expressions/description.md`
- `work/issues/001-fix-incorrect-indentation-after-match-expressions/implementation/` directory
- Structured issue documentation following Agile standards

## Standalone Nature
- Issues are independent of epics
- Self-contained with complete context
- Suitable for bugs and small features that don't require epic-level planning
- Can be completed in isolation without complex dependencies
