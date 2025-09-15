---
description: Work on an existing GitHub issue using a specialized agent
argument-hint: [issue-number] [agent]
---

# Issue Work Command

## Parameters
- `issue_number`: The GitHub issue number (e.g., "1", "2", "3")
- `agent`: The specialized agent to use for working on the issue

## Behavior

1. **Fetch GitHub Issue**
   - Retrieves the issue details from GitHub repository
   - Loads issue title, description, labels, and current status
   - Validates that the issue exists and is accessible

2. **Agent Assignment**
   - Launch the specified agent with the GitHub issue context
   - Provide the agent with:
     - Complete GitHub issue description and requirements
     - Relevant file paths and codebase context
     - Clear implementation guidance from issue content

3. **Available Agents**
   - `zig-systems-expert`: For Zig code implementation, memory management, and systems programming
   - `general-purpose`: For general implementation tasks and research
   - `backend-database-architect`: For performance optimization and system architecture
   - `tech-project-manager`: For code review and implementation planning

3. **Agent Context**
   The agent will receive:
   - Full GitHub issue description including acceptance criteria
   - Implementation notes and technical requirements from issue content
   - Testing requirements and definition of done
   - Relevant file paths mentioned in the GitHub issue

4. **Progress Tracking**
   - Agent progress is posted as comments on the GitHub issue
   - Status updates are reflected in GitHub issue labels
   - Final implementation results are documented in issue comments
   - Issues are automatically closed when work is completed

## Agent Selection Guidelines

### zig-systems-expert
Use for issues involving:
- Zig code implementation (adding new node types, formatter logic)
- Memory management and performance optimization
- Systems programming tasks
- Core formatter architecture changes

### general-purpose
Use for issues involving:
- Research and codebase analysis
- File searching and pattern identification
- General implementation tasks
- Multi-step problem solving

### backend-database-architect
Use for issues involving:
- Performance optimization
- System architecture decisions
- Complex algorithm implementation

### tech-project-manager
Use for issues involving:
- Code review and quality assessment
- Implementation planning and specification
- Project coordination tasks

## Example Usage
```
issue:work 3 zig-systems-expert
issue:work 4 general-purpose
issue:work 5 zig-systems-expert
```

## GitHub Integration

### Issue Context Provided to Agent
The agent will receive a comprehensive prompt including:

#### GitHub Issue Information
- Issue number, title, and GitHub URL
- Complete issue description and problem statement
- Labels, status, and assignee information
- All comments and discussion history

#### Implementation Context
- Relevant file paths mentioned in the issue
- Architecture overview from CLAUDE.md
- Development guidelines and practices
- Clear directive to implement the solution

### Progress Tracking
- **Issue Comments**: Agent posts progress updates as GitHub issue comments
- **Status Labels**: Issues are tagged with status labels (in-progress, review, etc.)
- **Completion**: Issues are closed automatically when work is finished
- **Documentation**: Final results and implementation notes are posted to the issue

## Success Criteria

The agent's work is considered complete when:
- All acceptance criteria from the GitHub issue are satisfied
- Implementation follows codebase conventions
- Tests pass (existing + any new tests)
- Code quality meets standards
- GitHub issue is updated with completion status

## Command Format
```
issue:work [github-issue-number] [agent]
```

Where:
- `github-issue-number`: GitHub issue number (1, 2, 3, etc.)
- `agent`: One of the available specialized agents

## Benefits
- **GitHub Native**: All tracking happens in GitHub's issue system
- **Team Visibility**: Progress is visible to all team members
- **History Preservation**: Complete implementation history in issue comments
- **Integration**: Works with GitHub notifications, mentions, and workflows