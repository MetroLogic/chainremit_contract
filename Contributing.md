# Contributing to starkRemit_contract

We welcome contributions to `starkRemit_contract`! Thank you for your interest in improving the project. Please follow these guidelines to ensure a smooth collaboration process.

## How to Contribute

1.  **Fork the repository:** Create your own copy of the project on GitHub.
2.  **Create a feature branch:** Before making changes, create a new branch from the `main` (or `develop`) branch:
    ```bash
    git checkout -b feat/your-feature-name # For new features
    # or
    git checkout -b fix/your-bug-fix-name  # For bug fixes
    ```
3.  **Make your changes:** Implement your feature or bug fix. Remember to adhere to the Coding Conventions outlined in the README.md.
4.  **Add tests:** Ensure your changes are well-tested. Add new tests if necessary to cover your code.
5.  **Ensure tests pass:** Run the full test suite to confirm your changes haven't introduced regressions:
    ```bash
    snforge test
    ```
6.  **Format your code:** Ensure your code adheres to the project's style guidelines:
    ```bash
    scarb fmt
    ```
7.  **Commit your changes:** Use clear and descriptive commit messages. We encourage following the Conventional Commits specification.
8.  **Push to your branch:** Push your changes to your forked repository:
    ```bash
    git push origin feat/your-feature-name
    ```
9.  **Open a Pull Request (PR):** Go to the original `starkRemit_contract` repository and open a Pull Request from your feature branch to the target branch (usually `main` or `develop`).
    *   Provide a clear title and description for your PR, explaining the "what" and "why" of your changes.
    *   Link any relevant issues (e.g., "Closes #123").
10. **Code Review:** Project maintainers will review your PR. Be responsive to feedback and make any necessary adjustments. Once approved, your contribution will be merged.

## Reporting Issues

*   Use the GitHub Issues tab in the main repository to report bugs or suggest new features.
*   **For Bug Reports:** Please provide as much detail as possible, including:
    *   Steps to reproduce the bug.
    *   Expected behavior.
    *   Actual behavior.
    *   Your environment (e.g., Scarb version, OS).
*   **For Feature Requests:** Clearly describe the proposed feature and its potential benefits.

Thank you for contributing!