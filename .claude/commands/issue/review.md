---
description: Review an existing issue specification using technical product management expertise
argument-hint: [issue-number]
---

# Issue Review Command

## Parameters
- `issue-number`: The number of the existing issue to review (e.g., 001, 002)

## Behavior

1. **Locate Issue**
   - Find the issue directory at `work/issues/{issue-number}-*/`
   - If not found, show error and list available issues

2. **Technical Product Manager Review**
   - Uses `@agent-technical-product-manager` for expert analysis
   - Reviews the issue specification for completeness and clarity
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
   - Creates or updates `work/issues/{issue-number}-*/review.md`
   - Provides structured feedback and recommendations
   - Identifies gaps, risks, and improvement opportunities
   - Suggests refinements to the issue specification

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
issue:review 001
```

This will:
- Locate `work/issues/001-fix-incorrect-indentation-after-match-expressions/`
- Engage technical product manager agent for comprehensive review
- Generate `work/issues/001-fix-incorrect-indentation-after-match-expressions/review.md`
- Provide actionable feedback and recommendations

## Agent Integration
- Always uses `@agent-technical-product-manager` for expert analysis
- Leverages product management expertise for holistic issue evaluation
- Provides professional-grade specification review and recommendations
- Ensures issues are implementation-ready before development begins