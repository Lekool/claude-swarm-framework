# Tracker Commands Reference

<!-- CUSTOMIZE: Uncomment the section matching your tracker and delete the rest. -->
<!-- All agents read this file so you only configure your tracker once. -->

<!-- === GitHub === -->
<!-- List issues: gh issue list --state open --json number,title,labels --limit 50 -->
<!-- Read issue: gh issue view <N> --comments -->
<!-- Post comment: gh issue comment <N> --body "..." -->
<!-- Add label: gh issue edit <N> --add-label "ready-to-assign" -->
<!-- Remove label: gh issue edit <N> --remove-label "more-research-needed" -->
<!-- Create label: gh label create "ready-to-merge" --color "0E8A16" --description "Reviewer recommends merge" -->
<!-- List PRs: gh pr list --head <branch> --json number,state -->
<!-- Open PR: gh pr create --base main --title "..." --body "..." -->
<!-- Read PR diff: gh pr diff <N> -->
<!-- Check CI: gh pr checks <N> -->
<!-- PR fields: state, mergedAt, title, body, number, headRefName, additions, deletions, files, statusCheckRollup -->
<!-- Note: gh issue view N only shows the body. Use --comments to see research context. -->

<!-- === GitLab === -->
<!-- List issues: glab issue list --state opened -->
<!-- Read issue: glab issue view <N> --comments -->
<!-- Post comment: glab issue note <N> --message "..." -->
<!-- Add label: glab issue update <N> --label "ready-to-assign" -->
<!-- Remove label: glab issue update <N> --unlabel "more-research-needed" -->
<!-- List MRs: glab mr list -->
<!-- Open MR: glab mr create --target-branch main --title "..." --description "..." -->
<!-- Read MR diff: glab mr diff <N> -->
<!-- Check CI: glab ci status -->

<!-- === Linear === -->
<!-- List issues: linear issue list --team <TEAM> --status "Todo" -->
<!-- Read issue: linear issue view <ID> -->
<!-- Post comment: linear comment create --issue <ID> --body "..." -->
<!-- Update status: linear issue update <ID> --status "In Progress" -->

<!-- === Jira === -->
<!-- List issues: jira issue list --project <KEY> --status "To Do" -->
<!-- Read issue: jira issue view <KEY> -->
<!-- Post comment: jira issue comment add <KEY> --body "..." -->
<!-- Transition: jira issue transition <KEY> "In Progress" -->

<!-- === Local files (no external tracker) === -->
<!-- List tasks: ls tasks/*.yaml -->
<!-- Read task: cat tasks/<name>.yaml -->
<!-- Post findings: write to tasks/<name>.research.md or tasks/<name>.review.md -->
<!-- Track status: update tasks/state.json directly -->
