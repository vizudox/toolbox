# Namecheap DDNS Sync

A lightweight, robust Bash script to synchronize your public IPv4 address with [Namecheap Dynamic DNS](https://www.namecheap.com/support/knowledgebase/subcategory/11/dynamic-dns/) records. Perfect for home labs, Raspberry Pi projects, or any server behind a Dynamic IP.

## Prerequisites

The script relies on standard Linux utilities:

- `curl`: For IP detection and API calls.
- `dig`: (from `dnsutils` or `bind9-host`) to query current DNS status.

## Getting Started

### 1. Installation

Clone the `toolbox` repository and navigate to the `networking/dynamic-dns/namecheap` directory:

```bash
git clone git@github.com:vizudox/toolbox.git
cd toolbox/networking/dynamic-dns/namecheap/
```

### 2. Configuration

Copy the template and fill in your domain details:

```bash
cp .env.example .env
```

Edit the `.env` file:

```bash
# The root domain you own (e.g., example.com)
DOMAIN=your_domain

# Your Namecheap Dynamic DNS Password
DDNS_PASSWORD=your_namecheap_ddns_password

# Space-separated list of records to update
RECORDS="@ test"
```

### 3. Execution

Give the script execution permissions and run it:

```bash
chmod +x ddns-sync.sh
./ddns-sync.sh
```
