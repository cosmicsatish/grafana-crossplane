package main

deny[msg] {
    sa := input.serviceAccounts[_]
    sa.role == "Admin"
    msg := sprintf("Security Violation: service account '%v' cannot have global role 'Admin'. Prefer role 'None' with specific fixedRoles.", [sa.name])
}

deny[msg] {
    sa := input.serviceAccounts[_]
    sa.role == "Editor"
    msg := sprintf("Security Violation: service account '%v' should not have global role 'Editor'. Prefer role 'None' with specific fixedRoles.", [sa.name])
}

deny[msg] {
    sa := input.serviceAccounts[_]
    ttl := object.get(sa, "tokenExpires", object.get(sa, "expiresIn", ""))
    ttl != ""
    not regex.match("^[0-9]+(s|sec|secs|second|seconds|min|mins|minute|minutes|h|hr|hrs|hour|hours|d|day|days|m|mo|mon|month|months|y|yr|yrs|year|years)$", lower(ttl))
    msg := sprintf("Compliance Violation: service account '%v' has invalid token lifetime '%v'. Use values such as 30d, 6m, 5min, or 1y.", [sa.name, ttl])
}

deny[msg] {
    folder := input.folders[_]
    not folder.title
    msg := "Schema Violation: folder entry is missing title."
}

deny[msg] {
    team := input.teams[_]
    not team.name
    msg := "Schema Violation: team entry is missing name."
}
