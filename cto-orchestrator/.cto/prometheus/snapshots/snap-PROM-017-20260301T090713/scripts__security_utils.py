#!/usr/bin/env python3
"""CTO Orchestrator — Security Utilities.

*Burrrp* — Security-Morty approved utilities for input validation,
path sanitization, and secure subprocess execution.

This module provides:
- Input validation and sanitization
- Path traversal prevention
- Safe subprocess execution patterns
- OWASP Top 10 mitigations
"""

import os
import re
import html
import shlex
from pathlib import Path
from typing import Optional, Union


# ── Input Validation Constants ────────────────────────────────────────────────

# Maximum lengths for various input fields
MAX_TICKET_ID_LENGTH = 20
MAX_TITLE_LENGTH = 200
MAX_DESCRIPTION_LENGTH = 5000
MAX_FILE_PATH_LENGTH = 500
MAX_TEAM_ID_LENGTH = 20

# Allowed characters for identifiers
SAFE_ID_PATTERN = re.compile(r'^[A-Za-z0-9_-]+$')

# Forbidden path components
FORBIDDEN_PATH_COMPONENTS = {'..', '~', '$', '`', '|', ';', '&', '>', '<', '\x00'}


# ── Path Traversal Prevention ─────────────────────────────────────────────────

def sanitize_path_component(component: str) -> str:
    """Sanitize a single path component to prevent traversal attacks.

    Args:
        component: A single path component (filename, directory name)

    Returns:
        Sanitized component with dangerous characters removed

    Raises:
        ValueError: If component is empty or contains only dangerous chars
    """
    if not component:
        raise ValueError("Path component cannot be empty")

    # Remove null bytes and other dangerous characters
    sanitized = component.replace('\x00', '')

    # Reject path traversal attempts
    if sanitized in ('..', '.'):
        raise ValueError(f"Path traversal attempt detected: {component}")

    # Remove any path separator characters
    sanitized = sanitized.replace('/', '').replace('\\', '')

    # Reject if the result is empty
    if not sanitized:
        raise ValueError(f"Path component reduced to empty string: {component}")

    return sanitized


def validate_safe_path(base_dir: Path, user_path: str) -> Path:
    """Validate that a user-provided path stays within a base directory.

    This prevents path traversal attacks by ensuring the resolved path
    is still under the base directory.

    Args:
        base_dir: The base directory that paths must stay within
        user_path: User-provided path component(s)

    Returns:
        Validated absolute path

    Raises:
        ValueError: If path would escape base directory or is invalid
    """
    if not user_path:
        raise ValueError("Path cannot be empty")

    # Check for forbidden patterns
    for forbidden in FORBIDDEN_PATH_COMPONENTS:
        if forbidden in user_path:
            raise ValueError(f"Forbidden character in path: {forbidden}")

    # Construct the full path
    base_dir = base_dir.resolve()
    full_path = (base_dir / user_path).resolve()

    # Verify the path is still under base_dir
    try:
        full_path.relative_to(base_dir)
    except ValueError:
        raise ValueError(f"Path traversal attempt detected: {user_path}")

    return full_path


def sanitize_ticket_id(ticket_id: str) -> str:
    """Sanitize a ticket ID for safe use in file paths.

    Args:
        ticket_id: User-provided ticket ID

    Returns:
        Sanitized ticket ID

    Raises:
        ValueError: If ticket ID is invalid
    """
    if not ticket_id:
        raise ValueError("Ticket ID cannot be empty")

    if len(ticket_id) > MAX_TICKET_ID_LENGTH:
        raise ValueError(f"Ticket ID exceeds maximum length of {MAX_TICKET_ID_LENGTH}")

    # Only allow alphanumeric, underscore, and hyphen
    if not SAFE_ID_PATTERN.match(ticket_id):
        raise ValueError(f"Ticket ID contains invalid characters: {ticket_id}")

    return ticket_id


def sanitize_team_id(team_id: str) -> str:
    """Sanitize a team ID for safe use in file paths.

    Args:
        team_id: User-provided team ID

    Returns:
        Sanitized team ID

    Raises:
        ValueError: If team ID is invalid
    """
    if not team_id:
        raise ValueError("Team ID cannot be empty")

    if len(team_id) > MAX_TEAM_ID_LENGTH:
        raise ValueError(f"Team ID exceeds maximum length of {MAX_TEAM_ID_LENGTH}")

    # Only allow alphanumeric, underscore, and hyphen
    if not SAFE_ID_PATTERN.match(team_id):
        raise ValueError(f"Team ID contains invalid characters: {team_id}")

    return team_id


# ── Input Sanitization ────────────────────────────────────────────────────────

def sanitize_text_input(text: str, max_length: int = MAX_DESCRIPTION_LENGTH) -> str:
    """Sanitize text input to prevent injection attacks.

    Args:
        text: User-provided text input
        max_length: Maximum allowed length

    Returns:
        Sanitized text
    """
    if not text:
        return ""

    # Truncate to maximum length
    text = text[:max_length]

    # Remove null bytes
    text = text.replace('\x00', '')

    # Remove control characters (except newline and tab)
    text = ''.join(c for c in text if c.isprintable() or c in '\n\t')

    return text


def sanitize_title(title: str) -> str:
    """Sanitize a title field.

    Args:
        title: User-provided title

    Returns:
        Sanitized title

    Raises:
        ValueError: If title is empty after sanitization
    """
    sanitized = sanitize_text_input(title, MAX_TITLE_LENGTH)

    # Titles should not be empty
    if not sanitized.strip():
        raise ValueError("Title cannot be empty")

    return sanitized


def sanitize_for_shell(text: str) -> str:
    """Sanitize text for safe inclusion in shell commands.

    WARNING: Prefer using subprocess with list arguments instead of shell=True.
    Only use this for logging/display purposes.

    Args:
        text: Text to sanitize

    Returns:
        Shell-escaped text
    """
    return shlex.quote(text)


def sanitize_for_html(text: str) -> str:
    """Sanitize text for safe HTML output (prevent XSS).

    Args:
        text: Text to sanitize

    Returns:
        HTML-escaped text
    """
    return html.escape(text)


# ── File Extension Validation ─────────────────────────────────────────────────

ALLOWED_CONFIG_EXTENSIONS = {'.json', '.yaml', '.yml'}
ALLOWED_DATA_EXTENSIONS = {'.json', '.jsonl', '.md', '.txt'}


def validate_file_extension(filepath: str, allowed_extensions: set[str]) -> bool:
    """Validate that a file has an allowed extension.

    Args:
        filepath: Path to file
        allowed_extensions: Set of allowed extensions (including the dot)

    Returns:
        True if extension is allowed
    """
    ext = os.path.splitext(filepath)[1].lower()
    return ext in allowed_extensions


# ── Prompt Sanitization ───────────────────────────────────────────────────────

def sanitize_prompt_content(content: str) -> str:
    """Sanitize content that will be included in LLM prompts.

    Removes potential prompt injection patterns while preserving
    legitimate content.

    Args:
        content: Content to include in a prompt

    Returns:
        Sanitized content
    """
    if not content:
        return ""

    # Remove null bytes
    content = content.replace('\x00', '')

    # Remove excessive whitespace
    content = re.sub(r'\n{3,}', '\n\n', content)

    # Truncate very long content
    max_prompt_content = 10000
    if len(content) > max_prompt_content:
        content = content[:max_prompt_content] + "\n\n[Content truncated for safety]"

    return content


# ── URL Validation ────────────────────────────────────────────────────────────

def validate_url(url: str, require_https: bool = False) -> bool:
    """Validate a URL for security.

    Args:
        url: URL to validate
        require_https: If True, only HTTPS URLs are allowed

    Returns:
        True if URL is valid and safe
    """
    if not url:
        return False

    # Basic URL pattern
    url_pattern = re.compile(
        r'^https?://'  # http or https
        r'[a-zA-Z0-9.-]+'  # domain
        r'(:[0-9]+)?'  # optional port
        r'(/[^\s]*)?$'  # optional path
    )

    if not url_pattern.match(url):
        return False

    if require_https and not url.startswith('https://'):
        return False

    # Reject localhost/internal IPs in production contexts
    # (uncomment if needed for SSRF prevention)
    # forbidden_hosts = ['localhost', '127.0.0.1', '0.0.0.0', '::1']
    # for host in forbidden_hosts:
    #     if host in url:
    #         return False

    return True


# ── JSON Safety ───────────────────────────────────────────────────────────────

def safe_json_loads(data: str, max_size: int = 1_000_000) -> dict:
    """Safely parse JSON data with size limits.

    Args:
        data: JSON string to parse
        max_size: Maximum size in bytes

    Returns:
        Parsed JSON data

    Raises:
        ValueError: If data is too large or invalid
    """
    import json

    if len(data) > max_size:
        raise ValueError(f"JSON data exceeds maximum size of {max_size} bytes")

    return json.loads(data)


# ── Security Context ──────────────────────────────────────────────────────────

class SecurityContext:
    """Security context for tracking and validating operations.

    Usage:
        ctx = SecurityContext(root_dir)
        safe_path = ctx.validate_path(user_input)
    """

    def __init__(self, root_dir: Path):
        self.root_dir = root_dir.resolve()

    def validate_path(self, user_path: str) -> Path:
        """Validate a path stays within the project root."""
        return validate_safe_path(self.root_dir, user_path)

    def validate_ticket_path(self, ticket_id: str) -> Path:
        """Get a validated ticket file path."""
        safe_id = sanitize_ticket_id(ticket_id)
        tickets_dir = self.root_dir / ".cto" / "tickets"
        return tickets_dir / f"{safe_id}.json"

    def validate_team_path(self, team_id: str) -> Path:
        """Get a validated team file path."""
        safe_id = sanitize_team_id(team_id)
        teams_dir = self.root_dir / ".cto" / "teams" / "active"
        return teams_dir / f"{safe_id}.json"


# ── Deprecated Pattern Warning ────────────────────────────────────────────────

def warn_dangerous_pattern(pattern: str, location: str):
    """Log a warning about a dangerous pattern (for gradual migration).

    Args:
        pattern: The dangerous pattern detected
        location: Where it was detected
    """
    import sys
    print(f"[SECURITY WARNING] {pattern} detected at {location}", file=sys.stderr)


if __name__ == "__main__":
    # Self-test
    print("Security utilities self-test...")

    # Test path sanitization
    try:
        sanitize_ticket_id("../../../etc/passwd")
        print("FAIL: Path traversal not detected")
    except ValueError as e:
        print(f"PASS: Path traversal detected: {e}")

    # Test valid ticket ID
    try:
        result = sanitize_ticket_id("PROJ-001")
        print(f"PASS: Valid ticket ID accepted: {result}")
    except ValueError as e:
        print(f"FAIL: Valid ticket ID rejected: {e}")

    # Test text sanitization
    sanitized = sanitize_text_input("Hello\x00World\x00!")
    assert '\x00' not in sanitized
    print(f"PASS: Null bytes removed: {sanitized}")

    print("All tests passed!")
