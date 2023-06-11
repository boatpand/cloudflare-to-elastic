# pull log cloudflare to local storage
echo '{ "query":
  "query ListFirewallEvents($zoneTag: string, $filter: FirewallEventsAdaptiveFilter_InputObject) {
    viewer {
      zones(filter: { zoneTag: $zoneTag }) {
        firewallEventsAdaptive(
          filter: $filter
          limit: 10000
          orderBy: [datetime_DESC]
        ) {
          clientASNDescription
          clientAsn
          clientCountryName
          clientIP
          clientRefererScheme
          clientRefererHost
          clientRefererPath
          clientRefererQuery
          clientRequestScheme
          clientRequestHTTPHost
          clientRequestPath
          clientRequestQuery
          clientRequestHTTPMethodName
          clientRequestHTTPProtocol
          datetime
          userAgent
          edgeColoName
          edgeResponseStatus
          originResponseStatus
          kind
          matchIndex
          originatorRayName
          rayName
          sampleInterval
          action
          clientIPClass
          ref
          ruleId
          rulesetId
          source
        }
      }
    }
  }",
  "variables": {
    "zoneTag": "<zone ID>",
    "filter": {
      "datetime_geq": "2023-05-30T03:30:00Z",
      "datetime_leq": "2023-05-30T09:30:00Z"
    }
  }
}' | tr -d '\n' | curl \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Auth-Email: <email>" \
  -H "Authorization: Bearer <token>" \
  -s \
  -d @- \
  https://api.cloudflare.com/client/v4/graphql/ | jq -c  '.data.viewer.zones[].firewallEventsAdaptive[]'  > cloudflare-firewall-event.json

# add @timestamp field to elastic field format
while IFS= read -r line; do
    timestamp=$(jq .datetime <<< $line)
    modify="${line:1}"
    echo "{\"create\":{ }}\n{\"@timestamp\":$timestamp, $modify" >> "cloudflare-firewall-event2.json"
done < "cloudflare-firewall-event.json"

# BULK API to push JSON file to Index elasticsearch
curl -H "Content-Type: application/json" -k -u <user_elastic>:<password>m -XPOST https://localhost:9200/firewall-event-cloudflare/_bulk --data-binary @cloudflare-firewall-event2.json