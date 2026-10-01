# Phase 1 Demo Video Script (5 minutes maximum)

Screen-share `report.pdf` and move through it page by page. The times are cumulative, and the script is about 4 minutes 10 seconds of speech at a normal pace, so you have about 50 seconds of buffer for page turns and pauses. Speaker names are suggestions.

---

## PART 1: Team intro and setup flow (0:00 to 2:00)

### Page 1: intro, machine table, topology diagram, setup steps (0:00 to 1:10)
**Mayank:** Hello, we are Team 1: Vikrant, Asad, Mayank and Prashant. For Phase 1 we built a private network service platform on four MacBooks that share the same Wi-Fi. A client types a private name, `app.team1.test`. Our own DNS server turns it into an IP address, the client opens an HTTPS connection to our nginx edge, and nginx passes the request to one of two backend servers.

*(Point at the table.)* Mac 1, Vikrant, is the DNS server at 10.7.13.235. Mac 2, Asad, is the nginx edge and load balancer at 10.7.17.39, on port 8443. Mac 3, mine, is Backend A on port 3001. Mac 4, Prashant, is Backend B on port 3002.

*(Point at the diagram.)* The flow is: the client first asks Mac 1 for the address, then connects over HTTPS to Mac 2, which forwards the request round-robin to Backend A or Backend B.

*(Point at the setup steps.)* Our setup was: join the same network, record every address, ping every pair of machines, then build the DNS.

### Page 2: ping screenshots and dig (1:10 to 2:00)
**Mayank:** First we proved the LAN works. Here Mac 3 reaches all four machines, and Mac 1 pings Mac 2 and Mac 4: four packets each, zero percent loss.

**Vikrant:** Next is DNS. I run dnsmasq on Mac 1, and Mac 3 and Mac 4 use it as their resolver. This is `dig app.team1.test` from a client: the answer is 10.7.17.39, and the SERVER line shows our DNS server, not Google or the router.

---

## PART 2: How the configuration works (2:00 to 4:00)

### Page 3: dnsmasq config, DNS capture, backends, start of the nginx config (2:00 to 2:45)
**Vikrant:** This is the dnsmasq config. It listens on Mac 1's LAN address, not only localhost, so other Macs can use it, and both names point to the edge. In Wireshark, the client sends the query from port 58206 to our DNS server on port 53, and the answer is 10.7.17.39.

**Prashant:** Each backend is a small Python server on all interfaces, port 3001 or 3002. It answers `/` and `/api/status`, with an X-Backend header and `Cache-Control: max-age=60`.

**Asad:** On the edge, nginx has an upstream block listing both backends.

### Page 4: rest of the nginx config (2:45 to 3:00)
**Asad:** And a server block on port 8443 with our mkcert certificate, approved by our faculty. It terminates TLS and forwards round-robin. If one backend fails it retries on the other, and if both are down it returns a clear 502.

### Page 5: curl -v and load balancing (3:00 to 3:30)
**Asad:** Here is `curl -v` with the domain name and no `-k`. It shows TLS 1.3, the certificate name matches `app.team1.test`, the certificate verifies, and the response is HTTP 200. Below, repeated requests are served by both Backend A and Backend B.

### Page 6: caching and packet evidence (3:30 to 4:00)
**Mayank:** `Cache-Control: max-age=60` means a client may reuse the response for sixty seconds before asking again. In the capture, the TCP handshake is SYN, SYN-ACK, ACK from client port 56982 to port 8443. Then the TLS ClientHello and the ServerHello choosing TLS 1.3. After that there is only encrypted Application Data, which is why we cannot read the HTTP headers in Wireshark.

---

## PART 3: Failure demonstration (4:00 to 5:00)

### Page 7: stop one backend (4:00 to 4:50)
**Prashant:** For the failure demonstration we stopped Backend A on Mac 3. Before, requests were served by both backends. After, every response says X-Backend B and still returns HTTP 200. The layer affected is the application layer behind the load balancer. Port 3001 stopped accepting connections, so nginx used Backend B, while DNS, TCP to the edge and TLS were not affected. We restored it by restarting Backend A, and requests are again served by both backends. Thank you.

---

## Before you record and submit
- Maximum 5 minutes, maximum 500 MB, `.mp4`, 1080p recommended.
- File name: `CN_Phase1_[Section][TeamName][InfraType].mp4`.
- Upload to Google Drive, Share, "Anyone with the link can view".
- Test the link in an incognito window before submitting.
- The failure demonstration (D3) must be in the video.
