# Phase 1: Build and Observe the Network - Detailed Guide

This guide breaks down every mandatory task from the project document into a chronological, actionable sequence. 

---

## Step 1: Establish the Private LAN (Task A)
**Goal:** Ensure all laptops can communicate and assign roles.

1. **Connect:** Ensure all 4 laptops are connected to the exact same Wi-Fi network.
2. **Assign Roles:** Decide who will be Mac 1 (DNS), Mac 2 (Nginx/Edge), Mac 3 (Backend A), and Mac 4 (Backend B).
3. **Get IPs:** On each Mac, open the Terminal and find its IP address:
   ```bash
   ipconfig getifaddr en0
   ```
   *(Record these IPs, you will need them for every following step. Also record the Subnet Mask, Router, and MAC Address for your final report).*
4. **Test Connectivity:** From Mac 1, ping Mac 2, 3, and 4 to ensure they are reachable:
   ```bash
   ping -c 4 <Mac-2-IP>
   ```

---

## Step 2: Build the Backend Services (Tasks C & F)
**Goal:** Run simple HTTP applications on Mac 3 and Mac 4.

1. **The Code:** You need a tiny web server. (I can write this for you in Python or Node.js). 
2. **Mac 3 (Backend A):**
   * Run the server so it listens on **Port 3001**.
   * It must respond to `GET /` and `GET /api/status`.
   * It must include a custom HTTP header in its response: `X-Backend: A`.
   * It must include a `Cache-Control: max-age=60` header (this satisfies Task F).
3. **Mac 4 (Backend B):**
   * Run a nearly identical server, but listen on **Port 3002**.
   * Its custom header must be `X-Backend: B`.
4. **Test:** From Mac 2, try to reach them using `curl http://<Mac-3-IP>:3001`.

---

## Step 3: Nginx Edge & Load Balancer (Task D)
**Goal:** Route traffic through a single entry point that balances between the two backends.

1. **Install Nginx:** On Mac 2, install Nginx using Homebrew:
   ```bash
   brew install nginx
   ```
2. **Configure Load Balancing:** You will edit the `nginx.conf` file (I will generate this for you). You will define an `upstream` block containing the IP addresses of Mac 3 and Mac 4.
3. **Configure Routing:** You will configure a `server` block to listen for requests to `app.teamX.test` and proxy them to the `upstream` block. Nginx will automatically use "round-robin" to alternate between Mac 3 and Mac 4 on each request.

---

## Step 4: Add HTTPS / TLS (Task E)
**Goal:** Secure the Nginx edge with a TLS certificate.

1. **Generate Certificates:** On Mac 2, the easiest way is using a tool called `mkcert`:
   ```bash
   brew install mkcert
   mkcert -install
   mkcert app.team1.test api.team1.test
   ```
2. **Install on Nginx:** Move the generated certificate `.pem` and `.key` files to your Nginx directory and update `nginx.conf` to listen on **Port 443** (HTTPS) using these files.
3. **Trust the Certificate:** The client laptops (Mac 3, Mac 4) need to trust this certificate. You will copy the `rootCA.pem` file from Mac 2 over to the other Macs and add it to their macOS Keychain (Trust Store).

---

## Step 5: Configure the Private DNS (Task B)
**Goal:** Allow clients to type `app.teamX.test` instead of IP addresses.

1. **Install DNS Server:** On Mac 1, install `dnsmasq`:
   ```bash
   brew install dnsmasq
   ```
2. **Configure Records:** Edit the `dnsmasq.conf` file to point your domain to Mac 2's IP:
   ```text
   address=/team1.test/<Mac-2-IP-Address>
   ```
3. **Start the Service:** `sudo brew services start dnsmasq`
4. **Configure Clients:** On Mac 3 and Mac 4 (which act as test clients), go to **System Settings -> Network -> Wi-Fi -> Details -> DNS**. Add the IP address of Mac 1 as the primary DNS server.
5. **Test:** On a client Mac, run:
   ```bash
   dig app.team1.test
   ```
   It should return Mac 2's IP address!

---

## Step 6: Evidence & Packet Capture (Task G)
**Goal:** Prove it all works at the network layer.

1. Open **Wireshark** on a client Mac.
2. Start capturing on your Wi-Fi interface (`en0`).
3. Open a browser and go to `https://app.team1.test`.
4. Stop the capture. You need to find and screenshot:
   * **DNS:** The UDP query asking for `app.team1.test` and the response.
   * **TCP:** The SYN -> SYN-ACK -> ACK three-way handshake.
   * **TLS:** The ClientHello, ServerHello, and Certificate packets.
   * **HTTP:** (Use browser dev tools or `curl -v`) to show the encrypted payload, the `X-Backend` headers alternating, and the `Cache-Control` header.

---

## Step 7: Required Failure Demonstrations
**Goal:** Deliberately break the system and explain why it fails.

Run through these 5 scenarios and document the results:
1. **Wrong DNS:** Change a client's DNS settings to `8.8.8.8`. Show that `app.team1.test` fails to resolve, but you can still `ping` IPs directly.
2. **Wrong IP Record:** Change `dnsmasq.conf` to point to a fake IP. Show that `dig` works, but the website won't load.
3. **One Backend Stopped:** Stop the server script on Mac 3. Show that the website still loads (Nginx routes everything to Mac 4).
4. **Both Backends Stopped:** Stop the script on Mac 4 too. Show Nginx returning a `502 Bad Gateway` error.
5. **Wrong Port:** Try `curl https://app.team1.test:9999`. Show that the connection is refused.

---

## Step 8: Final Deliverables
Gather everything into your final submission folder:
1. **Architecture Document:** Network diagram, IP table, request-flow diagram.
2. **Configuration Bundle:** Your `dnsmasq.conf`, `nginx.conf`, backend source code, and certificate notes.
3. **Evidence Folder:** All the screenshots from Step 6 and Step 7.
