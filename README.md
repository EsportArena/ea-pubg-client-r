# pubgR

R client package for the PUBG API

## Overview

`pubgR` provides a simple R6 class interface for interacting with the official PUBG API. It handles authentication, rate limiting, and provides convenient methods for retrieving player data.

## Features

- **Simple R6 interface** for PUBG API interactions
- **Automatic rate limiting** (respects 10 requests/second limit)
- **Built-in caching** (5-minute default TTL)
- **Chunked requests** for multiple players (handles >10 players automatically)
- **Clean error handling** with informative messages

## Installation

Install directly from GitHub:

```r
# Install from GitHub
remotes::install_github("yourusername/pubg-client-r")
```

## Usage

### Basic Setup

```r
library(pubgR)

# Initialize client with your API key
client <- PUBGClient$new(api_key = "your_pubg_api_key_here")
```

### Get Player Information

```r
# Single player
player_data <- client$getPlayerInfo("shroud")

# Multiple players (automatically chunked if >10 players)
players_data <- client$getPlayerInfo(c("shroud", "chocoTaco", "DrDisrespect"))

# Access player data
player_name <- players_data$data[[1]]$attributes$name
player_matches <- players_data$data[[1]]$relationships$matches$data
```

### Extract Match IDs

```r
# Get all match IDs for players
all_matches <- unlist(lapply(players_data$data, function(player) {
  sapply(player$relationships$matches$data, function(match) match$id)
}))

print(length(all_matches))  # Number of matches found
```

## API Reference

### PUBGClient Class

#### Constructor

```r
PUBGClient$new(api_key, platform = "steam")
```

**Parameters:**
- `api_key`: Your PUBG API key (required)
- `platform`: Gaming platform (default: "steam")

#### Methods

##### `getPlayerInfo(playerNames)`

Retrieves player information including recent matches.

**Parameters:**
- `playerNames`: Character vector of player names (1 or more)

**Returns:**
- List containing player data with match information

**Example:**
```r
# Single player
player <- client$getPlayerInfo("playerName")

# Multiple players  
players <- client$getPlayerInfo(c("player1", "player2", "player3"))
```

## Rate Limiting

The client automatically handles PUBG API rate limits:
- **10 requests per second** maximum
- Automatic backoff and retry on rate limit errors
- Built-in exponential backoff for failed requests

## Caching

Responses are automatically cached for 5 minutes to reduce API calls:
- Player data cached by player names
- Cache automatically expires after 5 minutes
- Helps stay within rate limits for repeated requests

## Error Handling

The client provides informative error messages for common issues:
- Invalid API keys
- Network connection problems  
- API rate limit exceeded
- Invalid player names

## Requirements

- R >= 3.5.0
- Dependencies: `R6`, `httr`, `jsonlite`

## Configuration

### Environment Variables

You can store your API key as an environment variable:

```r
# In your .Renviron file
PUBG_API_KEY=your_api_key_here

# In your R code
client <- PUBGClient$new(Sys.getenv("PUBG_API_KEY"))
```

### Supported Platforms

Currently supports these gaming platforms:
- `steam` (default)
- `xbox`
- `psn`
- `stadia`

## Examples

### Complete Workflow

```r
library(pubgR)

# Initialize client
client <- PUBGClient$new(Sys.getenv("PUBG_API_KEY"))

# Get data for multiple players
player_names <- c("shroud", "chocoTaco", "DrDisrespect")
player_data <- client$getPlayerInfo(player_names)

# Extract all match IDs
match_ids <- unlist(lapply(player_data$data, function(player) {
  sapply(player$relationships$matches$data, function(match) match$id)
}))

# Show results
cat("Found", length(match_ids), "total matches for", length(player_names), "players\n")
cat("Unique matches:", length(unique(match_ids)), "\n")
```

### Integration with Database

```r
# Get existing match IDs from your database
existing_matches <- your_database_query_function()

# Get new matches only
all_match_ids <- extract_match_ids_from_api()
new_matches <- setdiff(all_match_ids, existing_matches)

cat("Found", length(new_matches), "new matches to process\n")
```

## License

MIT License - see LICENSE file for details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Support

For issues or questions:
- Open an issue on GitHub
- Check the [PUBG API documentation](https://documentation.pubg.com/)

---

**Note:** You need a valid PUBG API key to use this package. Get one from the [PUBG Developer Portal](https://developer.pubg.com/).
