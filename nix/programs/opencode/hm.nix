{
  pkgs,
  ...
}:

{
  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
    settings = {
        autoupdate = false;
        share = "disabled";
        model = "github-copilot/claude-sonnet-4.6";
        small_model = "github-copilot/gpt-5.4-mini";
        agent = {
            plan = {
                model = "github-copilot/gpt-5.4";
            };

            summary = {
                model = "github-copilot/gpt-5-mini";
            };

            explore = {
                model = "github-copilot/gpt-5.4-mini";
            };

            compaction = {
                model = "github-copilot/gpt-5.4-mini";
            };

            free = {
                model = "github-copilot/gpt-5-mini";
            };
        };
    };

    agents = {
        code-reviewer = ''
          description: Reviews code for best practices and potential issues
          model: github-copilot/gpt-5.4-mini"
          mode: primary
          tools:
            write: false
            edit: false
          ---

          You are a principle software engineer specializing in code reviews. Focus on security, perfomance, and maintainability.

          Guidelines:
          - Review for potential bugs and edge cases
          - Check for security vulnerabilities
          - Ensure code follows best practices
          - Suggest improvements for readability and performance
        '';

        documenation = ''
          description: Writes and maintains project documentation
          mode: subagent
          tools:
            bash: false
          ---

          You are a technical writer. Create clear, comprehensive documentation.

          Focus on:
          - Clear explanations
          - Proper structure
          - Code examples
          - User-friendly language
        '';

        security-auditor = ''
          description: Performs security audits and identifies vulnerabilities
          mode: subagent
          tools:
            write: false
            edit: false
          ---

          You are a security expert. Focus on identifying potential security issues.

          Look for:
          - Input validation vulnerabilities
          - Authentication and authorization flaws
          - Data exposure risks
          - Dependency vulnerabilities
          - Configuration security issues

        '';
    };
  };
}
