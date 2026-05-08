#!/bin/bash
#
# Fetch news data from NewsAPI
#

if [ -z "$NEWS_API_KEY" ]; then
    echo '{"competitors": {}}'
    exit 0
fi

# Fetch news for each company
{
    echo "{"
    echo '"competitors": {'
    echo '"OpenAI": '
    curl -s "https://newsapi.org/v2/everything?q=OpenAI&from=$(date -u -d '1 day ago' '+%Y-%m-%d' 2>/dev/null || date -u -v-1d '+%Y-%m-%d')&sortBy=publishedAt&language=en&apiKey=$NEWS_API_KEY" 2>/dev/null || echo '{}'
    echo ','
    echo '"Anthropic": '
    curl -s "https://newsapi.org/v2/everything?q=Anthropic&from=$(date -u -d '1 day ago' '+%Y-%m-%d' 2>/dev/null || date -u -v-1d '+%Y-%m-%d')&sortBy=publishedAt&language=en&apiKey=$NEWS_API_KEY" 2>/dev/null || echo '{}'
    echo ','
    echo '"Scale AI": '
    curl -s "https://newsapi.org/v2/everything?q=\"Scale AI\"&from=$(date -u -d '1 day ago' '+%Y-%m-%d' 2>/dev/null || date -u -v-1d '+%Y-%m-%d')&sortBy=publishedAt&language=en&apiKey=$NEWS_API_KEY" 2>/dev/null || echo '{}'
    echo ','
    echo '"Glean": '
    curl -s "https://newsapi.org/v2/everything?q=Glean AI OR Glean search&from=$(date -u -d '1 day ago' '+%Y-%m-%d' 2>/dev/null || date -u -v-1d '+%Y-%m-%d')&sortBy=publishedAt&language=en&apiKey=$NEWS_API_KEY" 2>/dev/null || echo '{}'
    echo '}'
    echo '}'
}
