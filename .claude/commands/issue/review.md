---
description: Review an existing GitHub issue using technical product management expertise
argument-hint: [issue-number]
allowed-tools: mcp__github__get_issue, mcp__github__list_issue_types, mcp__github__search_issues, mcp__github__add_issue_comment, mcp__github__list_issues, mcp__github__list_sub_issues, mcp__github__update_issue, mcp__github__reprioritize_sub_issue, mcp__github__create_sub_issue
---

# Issue Review Command

## Parameters
- `issue-number`: The GitHub issue number to review (e.g., 1, 2, 3)

## Behavior

1. **Fetch GitHub Issue**
   - Retrieves the issue from the GitHub repository
   - Loads issue title, description, labels, and comments
   - Validates that the issue exists and is accessible

2. **Technical Product Manager Review**
   - Uses `technical-product-manager` agent for expert analysis
   - Reviews the GitHub issue specification for completeness and clarity
   - Evaluates technical feasibility and implementation approach
   - Assesses acceptance criteria and definition of done

3. **Review Focus Areas**
   - **Specification Clarity**: Is the issue well-defined and unambiguous?
   - **Technical Feasibility**: Is the proposed solution technically sound?
   - **Acceptance Criteria**: Are the success conditions specific and testable?
   - **Scope Appropriateness**: Is this appropriately scoped as a standalone issue?
   - **Implementation Approach**: Are the technical notes comprehensive?
   - **Testing Strategy**: Is the validation approach adequate?

4. **Review Output**
   - Posts comprehensive review feedback as a GitHub issue comment
   - Provides structured feedback and recommendations
   - Identifies gaps, risks, and improvement opportunities
   - Suggests refinements to the issue specification
   - Updates issue labels based on review outcome

## Technical Product Manager Analysis

The agent will provide:

### Specification Assessment
- **Clarity Score**: How well-defined is the issue?
- **Completeness Check**: Are all necessary details included?
- **Ambiguity Identification**: What needs clarification?
- **User Impact Analysis**: How does this affect end users?

### Technical Review
- **Implementation Feasibility**: Can this be built as described?
- **Technical Complexity**: Effort and skill requirements
- **Architecture Impact**: Effects on existing codebase
- **Risk Assessment**: Potential implementation challenges

### Process Evaluation
- **Acceptance Criteria Quality**: Are criteria specific and measurable?
- **Testing Adequacy**: Is the validation approach sufficient?
- **Definition of Done**: Is completion clearly defined?
- **Documentation Needs**: What additional documentation is required?

### Recommendations
- **Specification Improvements**: Suggested changes to issue description
- **Implementation Suggestions**: Technical approach recommendations
- **Risk Mitigation**: How to address identified risks
- **Success Metrics**: How to measure successful completion

## Review Document Structure

The generated `review.md` will include:

### Review Summary
- Issue title and current specification version
- Review date and reviewer (technical-product-manager agent)
- Overall assessment and recommendation (Approve/Revise/Reject)

### Detailed Analysis
- **Strengths**: What's well-defined in the current specification
- **Weaknesses**: Areas needing improvement or clarification
- **Gaps**: Missing information or considerations
- **Risks**: Potential implementation or delivery challenges

### Actionable Recommendations
- **Immediate Actions**: Changes needed before implementation
- **Technical Considerations**: Implementation approach suggestions
- **Process Improvements**: How to better define similar issues in future
- **Success Criteria**: Additional validation requirements

### Implementation Readiness
- **Ready for Development**: Go/No-Go assessment
- **Prerequisite Work**: What needs to happen first
- **Resource Requirements**: Skills and effort needed
- **Timeline Considerations**: Complexity and dependency factors

## Example Usage
```
issue:review 3
```

This will:
- Fetch GitHub issue #3 from the repository
- Engage technical product manager agent for comprehensive review
- Post detailed review feedback as a comment on the GitHub issue
- Update issue labels based on review outcome (e.g., "needs-clarification", "ready-for-implementation")

## GitHub Integration
- **Issue Comments**: Review feedback posted directly to GitHub issue
- **Label Management**: Issues are tagged based on review outcome
- **Team Collaboration**: Review is visible to all team members
- **History Tracking**: Complete review history preserved in issue comments

## Agent Integration
- Always uses `technical-product-manager` agent for expert analysis
- Leverages product management expertise for holistic issue evaluation
- Provides professional-grade specification review and recommendations
- Ensures issues are implementation-ready before development begins

## Benefits
- **GitHub Native**: All review feedback integrated with GitHub's issue system
- **Transparency**: Review process visible to entire team
- **Actionable Feedback**: Specific recommendations for issue improvement
- **Quality Assurance**: Professional review before implementation begins
