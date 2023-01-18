# Octory ITOPS package source files

build_pkg.sh		--	Script to build a package
payload			--	Payload directory
resources		--	Resources folder containing the Requirements plist file
scripts			--	Scripts directory

Foursquare purchases its macOS devices from CDW or Apple, and these purchases are automatically assigned to its Apple Business Manager tenement. Assigned devices in Apple Business Manager are automatically assigned to Foursquare's Jamf Pro. Therefore, they will appear in the scoping of the Foursquare Labs Zero Touch Provisioning PreStage Enrollments. If the macOS devices fail to produce the Zero Touch Provisioning workflow during device activation, please verify that it is enabled in the prestage scoping.

An internet connection is required for a successful zero-touch enrollment. A Foursquare employee must ensure that their macOS device can connect to a wired or wireless network using WPA2/3 Personal security. Any attempt to perform the setup without a network connection may bypass the zero-touch enrollment process.

During zero-touch enrollment, the employee is prompted for their Foursquare JumpCloud username and password. The configuration is provided by the Foursquare Labs Zero Touch Provisioning PreStage Enrollment, which requires authentication. This authentication is performed via JumpCloud's LDAP. Once authenticated, the user's account is automatically created using their full name, username, and password. All Setup Assistant prompts will be skipped, and the login window will display if the process is successful.

Once the PreStage process is complete, a Jamf Pro policy will install a package on the macOS device to perform that application provisioning. The package consists of the following components: Octory app, Octory CLI notifier binary, Octory privilege helper tool, Octory resources, Octory scripts, and Apple launch daemons for Octory privilege helper and Octory app. The Octory launch daemon will launch a script to launch the Octory application for visual progress and perform the application provisioning by installing the required policies in a serialized workflow.

Upon successful completion, the macOS device will restart, and the Foursquare employee must log in and enable FileVault when prompted during their login.

Appendix:
Apple is a technology company specializing in consumer electronics, software, and online services.

Apple Business Manager is a simple, web-based portal for IT administrators that works with third-party mobile device management (MDM) solutions so that you can easily automate MDM enrollment and simplify initial device setup without having to touch or prepare the devices before users get them physically.

CDW is a third-party provider of information technology solutions to business, government, education, and healthcare customers.

Jamf Pro, developed by Jamf, is a comprehensive management system for Apple macOS and iOS devices that Foursquare IT uses to proactively manage the entire lifecycle of all Apple devices, including deploying and maintaining software and responding to security threats, distributing settings, and analyzing inventory data.

Jamf Pro Policies allows remote automation of everyday management tasks on managed computers, such as running scripts, managing accounts, and distributing software.

Octory is a highly customizable and elegant macOS application to onboard, support, and manage macOS devices.

PreStage enrollment stores enrollments and Mac computer setup settings in Jamf Pro and use them to enroll new Mac computers with Jamf Pro.
