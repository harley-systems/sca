# VHS Demo Tape for SCA Complete Walkthrough
# https://github.com/charmbracelet/vhs
#
# This demo shows the complete flow from installation to issuing a user certificate
# using YubiKey hardware security.
#
# Prerequisites:
# - YubiKey inserted with sub-CA already configured
# - PIN file configured for subca
# - Run from a clean state or use fresh user name

Output walkthrough.gif

Set FontSize 13
Set Width 1000
Set Height 600
Set Theme "Dracula"
Set Padding 20
Set TypingSpeed 40ms

# Setup clean environment with colored prompt
Hide
Type "export PS1=$'\\[\\e[1;32m\\]sca\\[\\e[0m\\]:\\[\\e[1;34m\\]\\W\\[\\e[0m\\]\\$ '"
Enter
Type "cd /home/aharon/src/sca"
Enter
Type "clear"
Enter
Show

# Title
Type "# SCA - Complete Walkthrough: Installation to User Certificate"
Enter
Sleep 1s

# Part 1: Installation
Type "# Part 1: Installation"
Enter
Sleep 500ms

Type "make deploy"
Enter
Sleep 3s

Type "# Reload bash completion"
Enter
Type ". ~/.local/share/bash-completion/completions/sca"
Enter
Sleep 1s

# Part 2: Configuration
Type "# Part 2: View current configuration"
Enter
Sleep 500ms

Type "sca config get ca"
Enter
Sleep 1s

Type "sca config get subca"
Enter
Sleep 1s

# Part 3: YubiKey Status
Type "# Part 3: Check YubiKey status"
Enter
Sleep 500ms

Type "sca security_key info"
Enter
Sleep 3s

Type "# Verify sub-CA private key is working"
Enter
Type "sca security_key verify subca"
Enter
Sleep 3s

# Part 4: Create User Certificate
Type "# Part 4: Issue a new user certificate"
Enter
Sleep 500ms

Type "# Set user details"
Enter
Type "sca config set user demo-user"
Enter
Sleep 1s

# Create key
Type "# Create private key"
Enter
Type "sca create key user"
Enter
Sleep 2s

# Create CSR
Type "# Create certificate signing request"
Enter
Type "sca create csr user"
Enter
Sleep 2s

# Approve CSR (YubiKey operation - will read PIN from file, may need touch)
Type "# Sign with YubiKey-protected sub-CA (touch YubiKey if prompted)"
Enter
Sleep 500ms
Type "sca approve csr user"
Enter
Sleep 5s

# Create certificate
Type "# Create the certificate"
Enter
Type "sca create crt user"
Enter
Sleep 2s

# Part 5: Verify and Display
Type "# Part 5: Verify the certificate"
Enter
Sleep 500ms

Type "sca display crt user | head -30"
Enter
Sleep 4s

# Part 6: Export
Type "# Part 6: Export for deployment"
Enter
Sleep 500ms

Type "sca export crt_pub_ssh user"
Enter
Sleep 2s

Type "# Export PKCS#12 for mobile devices"
Enter
Type "sca export p12 -p demo123 user"
Enter
Sleep 2s

# Show transfer folder
Type "# Files ready in transfer folder"
Enter
Type "ls -la ~/.sca/transfer/"
Enter
Sleep 3s

# Final
Type "# Done! User certificate issued and exported."
Enter
Sleep 2s
