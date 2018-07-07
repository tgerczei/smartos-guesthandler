A makeshift solution to extend <a href="http://www.smartos.org">SmartOS</a> with the capability to order VM boot and shut-down sequences by priority. It leverages SMF 'hot-plugging' built into the platform as well as vmadm's ability to tag guests. Technically it mitigates the built-in auto-boot procedure by intervening in due time and afterwards starts/stops VMs in an order derived from the numerical value of the '<i>property</i>' tag. My use-case: a single toy rig running vanilla SmartOS acting as an all-in-one system providing a range of services including infrastructural ones like name resolution and IP address allocation as well as an edge firewall; each contained in a dedicated guest which will, in turn, depend on another.

A logical pre-requisite of all this is tagging the VMs ideally upon creation or otherwise:

<i>vmadm list -Ho uuid | while read UUID; do vmadm update $UUID \<\<\< "{\\"set_tags\\": {\\"priority\\": 0}}"; done</i>

This will tag all VMs with the priority of 0 which will leave them <strong>stopped</strong>. Afterwards an actual order needs to be established by assigning non-zero values to them one by one in ascending order where lesser values represent higher priorities - with the notable exception of 0 - and thus earlier start-up:

<i>vmadm update \<UUID\> \<\<\< "{\\"set_tags\\": {\\"priority\\": 100}}"</i>

...and so on. Informational messages are logged via the syslog facility as '<i>daemon.notice</i>' entries tracking the determined order as well as the outcome for every step taken. The solution comprises two services backed by the same single method script: one activated before <i>svc:/system/zones</i> in order to convince it not to start any guests and the actual payload starting once vmadmd is available to evaluate the tags and complete the sequence.

SMF will import the manifests (the XML documents in this repository) for the services upon boot-up when it initializes its repository, provided they are placed under a directory named <strong><i>/opt/custom/smf</i></strong>. The location of the method script is configurable via the service property <i>config/method_prefix</i>, defaulting to <strong><i>/opt/custom/bin</i></strong> - the file needs to be executable and this directory may have to be created first, unless another, already present one is chosen. The start-up delay defaults to <strong><i>30</i></strong> seconds, also configurable via the context environment variable <i>DELAY</i> for the method <i>start</i>. A grace period of <strong>5</strong> minutes is granted for shut-down, configurable via the context environment variables <i>GRACE_PERIOD</i> and <i>WAIT_INTERVAL</i> in the <i>stop</i> method.

In the future the method script might get re-written in node.js in order to make a more human-friendly dependency notation/handling possible. This is merely the shortest path.
