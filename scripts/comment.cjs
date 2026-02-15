module.exports = async ({ github, context, core, previewUrl }) => {
    const marker = "<!-- dokku-preview-url -->";
    const body = `${marker}\nPreview deployed: ${previewUrl}`;
    const { owner, repo } = context.repo;
    const issue_number = context.issue.number;

    const comments = await github.paginate(
        github.rest.issues.listComments,
        { owner, repo, issue_number, per_page: 100 },
    );

    const existing = comments.find(
        (comment) =>
            comment.user?.type === "Bot" && comment.body?.includes(marker),
    );

    if (existing) {
        await github.rest.issues.updateComment({
            owner,
            repo,
            comment_id: existing.id,
            body,
        });
        core.info(`Updated existing comment ${existing.id}`);
    } else {
        await github.rest.issues.createComment({
            owner,
            repo,
            issue_number,
            body,
        });
        core.info("Created new preview comment");
    }
};
