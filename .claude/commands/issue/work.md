---
description: Work on an existing issue using a specialized agent
argument-hint: [issue-number] [agent]
---

# Issue Work Command

## Parameters
- `issue_number`: The issue number (e.g., "001", "002", "003")
- `agent`: The specialized agent to use for working on the issue

## Behavior

1. **Validate Issue Exists**
   - Check that `work/issues/{issue-number}-*/` directory exists
   - Load the issue description from `description.md`

2. **Agent Assignment**
   - Launch the specified agent with the issue context
   - Provide the agent with:
     - Complete issue description and requirements
     - Relevant file paths and codebase context
     - Clear implementation guidance

3. **Available Agents**
   - `zig-systems-expert`: For Zig code implementation, memory management, and systems programming
   - `general-purpose`: For general implementation tasks and research
   - `backend-database-architect`: For performance optimization and system architecture
   - `tech-project-manager`: For code review and implementation planning

4. **Agent Context**
   The agent will receive:
   - Full issue description including acceptance criteria
   - Implementation notes and technical requirements
   - Testing requirements and definition of done
   - Relevant file paths from the issue

5. **Implementation Tracking**
   - Agent work is tracked in the `implementation/` directory
   - Progress updates should be documented
   - Final implementation should satisfy all acceptance criteria

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
issue:work 001 zig-systems-expert
issue:work 002 general-purpose
issue:work 003 zig-systems-expert
```

## Issue Context Provided to Agent

The agent will receive a comprehensive prompt including:

### Issue Information
- Issue number and title
- Problem statement and current/expected behavior
- Acceptance criteria and definition of done
- Implementation notes and technical guidance

### Codebase Context
- Relevant file paths mentioned in the issue
- Architecture overview from CLAUDE.md
- Development guidelines and practices

### Task Instructions
- Clear directive to implement the solution
- Testing requirements
- Code quality expectations
- Guidance on following existing patterns

## Implementation Directory Structure

Each issue's implementation work is tracked in:
```
work/issues/{issue-number}-{issue-name}/
├── description.md
└── implementation/
    ├── analysis.md (optional - agent's analysis)
    ├── implementation-plan.md (optional - detailed plan)
    └── progress.md (optional - implementation notes)
```

## Success Criteria

The agent's work is considered complete when:
- All acceptance criteria are satisfied
- Implementation follows codebase conventions
- Tests pass (existing + any new tests)
- Code quality meets standards
- Issue is resolved and verified

## Command Format
```
issue:work [issue-number] [agent]
```

Where:
- `issue-number`: 3-digit issue number (001, 002, 003, etc.)
- `agent`: One of the available specialized agents