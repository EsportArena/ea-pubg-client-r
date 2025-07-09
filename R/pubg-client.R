#' PUBG API Client
#'
#' @description R6 class for interacting with the PUBG API
#' @importFrom R6 R6Class
#' @importFrom httr VERB add_headers status_code content
#' @importFrom jsonlite fromJSON
#' @export
PUBGClient <- R6::R6Class(
  classname = "PUBGClient",

  # Public methods
  public = list(
    #' @field apiKey PUBG API key
    apiKey = NULL,

    #' @field baseUrl Base URL for PUBG API
    baseUrl = "https://api.pubg.com/shards/",

    #' @field platform Gaming platform (default: "steam")
    platform = NULL,

    #' @description Initialize PUBG client
    #' @param api_key Your PUBG API key
    #' @param platform Gaming platform (default: "steam")
    initialize = function(api_key, platform = "steam") {
      if (missing(api_key) || is.null(api_key) || api_key == "") {
        stop("api_key is required")
      }

      self$apiKey <- api_key
      self$platform <- platform
    },

    #' @description Get player information for one or more players
    #' @param playerNames Either a single player name or a vector of player names.
    #'   More than 10 players will be chunked into groups of 10 to avoid rate limiting.
    #' @return List containing player information
    getPlayerInfo = function(playerNames) {
      # Validate input
      if (!is.character(playerNames) || length(playerNames) == 0) {
        stop("playerNames must be a non-empty character vector")
      }

      # Check cache first
      cacheKey <- paste("players", paste(playerNames, collapse = ","), sep = "_")
      cached <- private$getCachedRequest(cacheKey)
      if (!is.null(cached)) {
        return(cached)
      }

      # Split players into chunks of 10
      chunks <- split(playerNames, ceiling(seq_along(playerNames) / 10))

      allPlayers <- list()
      for (chunk in chunks) {
        params <- list(
          "filter[playerNames]" = paste(chunk, collapse = ",")
        )
        response <- private$makeRequest("/players", params = params)
        if (!is.null(allPlayers$data)) {
          allPlayers$data <- c(allPlayers$data, response$data)
        } else {
          allPlayers <- response
        }
      }

      # Cache response
      private$setCachedRequest(cacheKey, allPlayers)
      return(allPlayers)
    }
  ),

  # Private methods
  private = list(
    # Internal state
    cache = new.env(parent = emptyenv()),
    requestTimes = NULL,

    # Handle API rate limiting (10 requests per second)
    handleRateLimit = function() {
      if (is.null(private$requestTimes)) {
        private$requestTimes <- numeric()
      }

      current_time <- Sys.time()
      private$requestTimes <- private$requestTimes[
        difftime(current_time, private$requestTimes, units = "secs") <= 1
      ]

      if (length(private$requestTimes) >= 10) {
        oldest_request <- min(private$requestTimes)
        wait_time <- as.numeric(difftime(oldest_request + 1, current_time, units = "secs"))
        if (wait_time > 0) {
          Sys.sleep(wait_time)
        }
      }
    },

    # Make an API request with retries
    makeRequest = function(endpoint, method = "GET", params = NULL, retries = 3) {
      for (i in 1:retries) {
        tryCatch(
          {
            private$handleRateLimit()

            url <- paste0(self$baseUrl, self$platform, endpoint)
            response <- httr::VERB(
              method,
              url,
              httr::add_headers(
                "Authorization" = paste("Bearer", self$apiKey),
                "Accept" = "application/vnd.api+json"
              ),
              query = params
            )

            private$requestTimes <- c(private$requestTimes, Sys.time())

            if (httr::status_code(response) == 429) {
              Sys.sleep(2^i) # Exponential backoff
              next
            }

            if (httr::status_code(response) != 200) {
              stop(paste("API request failed with status:", httr::status_code(response)))
            }

            content <- httr::content(response, "text", encoding = "UTF-8")
            return(private$parseResponse(content))
          },
          error = function(e) {
            if (i == retries) stop(e)
            Sys.sleep(2^i) # Exponential backoff
          }
        )
      }
    },

    # Parse API response
    parseResponse = function(content) {
      tryCatch(
        {
          parsed <- jsonlite::fromJSON(content, simplifyVector = FALSE)
          if (!is.null(parsed$errors)) {
            stop(parsed$errors[[1]]$detail)
          }
          parsed
        },
        error = function(e) {
          stop(paste("Failed to parse response:", e$message))
        }
      )
    },

    # Get cached request data
    getCachedRequest = function(key, ttl = 300) {
      cached <- private$cache[[key]]
      if (!is.null(cached) && difftime(Sys.time(), cached$time, units = "secs") < ttl) {
        return(cached$data)
      }
      NULL
    },

    # Cache request data
    setCachedRequest = function(key, data) {
      private$cache[[key]] <- list(
        data = data,
        time = Sys.time()
      )
    }
  )
)
