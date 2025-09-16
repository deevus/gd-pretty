---
description: Work on an existing GitHub issue using a specialized agent
argument-hint: [issue-number] [agent]
allowed-tools: mcp__github__get_issue, mcp__github__list_issue_types, mcp__github__search_issues, mcp__github__add_issue_comment, mcp__github__list_issues, mcp__github__list_sub_issues, mcp__github__update_issue, mcp__github__add_sub_issue, mcp__github__get_issue_comments
---

# Issue Work Command

## Context

- Issue slug: A short descriptive identifier for the issue
- Branch name: `issue-${issue_number}/${issue-slug}`

## Parameters
- `issue_number`: The GitHub issue number (e.g., "1", "2", "3")
- `agent`: The specialized agent to use for working on the issue

## Behavior

1. **Fetch GitHub Issue**
   - Retrieves the issue details from GitHub repository
   - Loads issue title, description, labels, and current status
   - Validates that the issue exists and is accessible

2. **Branch Management (Pre-Work)**
   - Create issue slug from issue title (lowercase, hyphenated)
   - Create branch name: `issue-${issue_number}/${issue-slug}`
   - Check if issue branch already exists
   - If branch doesn't exist, create it from main branch
   - Checkout the issue branch before starting work

3. **Agent Assignment**
   - Launch the specified agent with the GitHub issue context
   - Provide the agent with:
     - Complete GitHub issue description and requirements
     - Relevant file paths and codebase context
     - Clear implementation guidance from issue content
     - Current branch context and git workflow expectations

4. **Available Agents**
   - `zig-systems-expert`: For Zig code implementation, memory management, and systems programming
   - `general-purpose`: For general implementation tasks and research
   - `backend-database-architect`: For performance optimization and system architecture
   - `tech-project-manager`: For code review and implementation planning

5. **Agent Context**
   The agent will receive:
   - Full GitHub issue description including acceptance criteria
   - Implementation notes and technical requirements from issue content
   - Testing requirements and definition of done
   - Relevant file paths mentioned in the GitHub issue

6. **Progress Tracking**
   - For in-progress tasks, agent will check comments or reviews on the issue/pull request
   - Agent progress is posted as comments on the GitHub issue or Pull Request
   - Status updates are reflected in GitHub issue labels
   - Final implementation results are documented in issue comments
   - All work is conducted on the dedicated issue branch

7. **Post-Work Git Management**
   - Commit all changes to the issue branch with descriptive commit message
   - Push the issue branch to origin
   - Create a GitHub Pull Request from issue branch to main
   - Link the PR to the GitHub issue (using "Closes #issue_number" or "Fixes #issue_number")
   - Add appropriate labels and reviewers to the PR

8. **Completed Work**
   - Agent creates a comprehensive GitHub Pull Request with implementation summary
   - PR includes testing notes and verification steps
   - Issue is automatically linked and will be closed when PR is merged
   - Branch cleanup occurs after successful merge

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

## Implementation Workflow

### Pre-Work Steps (Before Agent Assignment)
1. **Issue Validation**: Fetch GitHub issue details and validate existence
2. **Branch Name Generation**:
   - Extract issue title and create slug (lowercase, hyphens for spaces)
   - Remove special characters and limit length
   - Format: `issue-{number}/{slug}` (e.g., `issue-15/fix-indentation-bug`)
3. **Git Branch Management**:
   ```bash
   # Check if branch exists
   git show-branch issue-{number}/{slug} 2>/dev/null

   # If branch doesn't exist, create from main
   git checkout main
   git pull origin main
   git checkout -b issue-{number}/{slug}

   # If branch exists, checkout and update
   git checkout issue-{number}/{slug}
   git pull origin issue-{number}/{slug}
   ```
4. **Agent Context Preparation**: Include branch name and git workflow in agent prompt

### Post-Work Steps (After Agent Completion)
1. **Commit Changes**:
   ```bash
   git add .
   git commit -m "feat: {issue title summary}

   Implements #{issue_number}: {brief description}

   - {key changes made}
   - {testing performed}

   Closes #{issue_number}"
   ```
2. **Push Branch**: `git push origin issue-{number}/{slug}`
3. **Create Pull Request**:
   - Title: "{type}: {issue title}"
   - Body: Links to issue, summary of changes, testing notes
   - Automatically link to issue using "Closes #{issue_number}"

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
- Current branch name and git workflow expectations
- Clear directive to implement the solution

#### Agent Responsibilities
The agent must:
- Work exclusively on the issue branch (never commit to main)
- Follow the repository's development practices (testing, linting, etc.)
- Implement the complete solution as specified in the issue
- Provide clear implementation notes for the final commit and PR
- NOT create commits or PRs themselves (handled by post-work automation)

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
- Code quality meets standards (linting, formatting)
- Changes are ready for commit (staged and ready)
- Agent provides implementation summary for commit message and PR

## Workflow Validation

Before running the command:
- Ensure you have a clean working directory
- Confirm main branch is up-to-date
- Verify GitHub credentials are configured

During execution:
- Monitor that work happens on the issue branch
- Validate that no commits are made to main
- Ensure agent follows development practices

After completion:
- Review changes before committing
- Verify PR links correctly to the issue
- Confirm all acceptance criteria are met

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
