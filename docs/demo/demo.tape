# VHS Demo Tape for SCA - Simple Certificate Authority
# https://github.com/charmbracelet/vhs

Output demo.gif

Set FontSize 14
Set Width 900
Set Height 500
Set Theme "Dracula"
Set Padding 20
Set TypingSpeed 50ms

# Setup clean environment
Hide
Type "export PS1='$ '"
Enter
Type "cd /home/aharon/src/sca"
Enter
Type "clear"
Enter
Show

# Start with intro
Type "# SCA - Simple Certificate Authority"
Enter
Sleep 500ms
Type "# A shell-based PKI management tool"
Enter
Sleep 1s

# Show help (abbreviated)
Type "sca --help | head -25"
Enter
Sleep 3s

# List available users
Type "sca list users"
Enter
Sleep 2s

# Set user for demo
Type "sca config set user aharon"
Enter
Sleep 1s

# Display the certificate (limited output)
Type "sca display crt user | head -20"
Enter
Sleep 3s

# Export as p12 for mobile VPN
Type "# Export PKCS#12 bundle for mobile VPN"
Enter
Sleep 1s

Type "sca export p12 -p demo123 user"
Enter
Sleep 2s

# Verify p12 contents
Type "# Verify the bundle contents"
Enter
Sleep 500ms

Type "sca display p12 -p demo123 ~/.sca/transfer/aharon.p12"
Enter
Sleep 4s

# Final message
Type "# Ready for StrongSwan, iOS, Android..."
Enter
Sleep 2s
