#!/usr/bin/env ruby

require "graphql/client"
require "graphql/client/http"
require "json"
require 'set'
require 'pp'

MAX_PAGES = 999

module GithubRepositories
  GITHUB_TOKEN = ENV['GITHUB_TOKEN']
  CACHE_REPO_DATA = ENV['CACHE_REPO_DATA'] == 'Y'

  unless GITHUB_TOKEN
    raise "You must set a GITHUB_TOKEN variable to query github"
  end

  HTTP = GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
    def headers(context)
      {"Authorization" => "token #{GITHUB_TOKEN}"}
    end
  end

  unless File.exist? "github_schema.json"
    puts "Querying and saving github graphql schema data to github_schema.json"
    GraphQL::Client.dump_schema(HTTP, "github_schema.json")
  end

  SCHEMA = GraphQL::Client.load_schema("github_schema.json")

  CLIENT = GraphQL::Client.new(schema: SCHEMA, execute: HTTP)

  REPO_QUERY = CLIENT.parse <<-'GRAPHQL'
query($orgname: String!, $repo: String!, $cursor: String) {
    organization(login: $orgname) {
      repository(name:$repo) {
        collaborators(first:100, after: $cursor) {
          pageInfo {
            endCursor
          }
          edges {
            node {
              name
              login
            }
            permission
          }
        }
      }
    }
  }
  GRAPHQL

TEAMS_QUERY = CLIENT.parse <<-'GRAPHQL'
query ($orgname: String!, $repo: String!, $cursor: String) {
  organization(login: $orgname) {
    teams(first:100, after: $cursor) {
      pageInfo {
       endCursor
      }
      edges {
        node {
          name
          id
          repositories(first: 100, query: $repo) {
            edges  {
              node {
                name
              }
            permission 
            }
          }
        }
      }
    }
  }
}
GRAPHQL

MEMBERS_QUERY = CLIENT.parse <<-'GRAPHQL'
query ($node_id: ID!, $cursor: String) {
  node(id: $node_id) {
   ... on Team {
      members(first:100, after: $cursor) {
        pageInfo {
          endCursor
        }
        edges {
          node {
            name
            login
          }
        }
      }
    }
  }
}
GRAPHQL

  class NestedKeyEmpty < StandardError  
  end  

  class RepositoryAdmins

    def initialize(orgname, reponame)
      @orgname = orgname
      @reponame = reponame
    end

    def checking_query(query, variables, *properties)
      response = CLIENT.query(query, variables: variables)
      unless response.errors.empty?
        raise response.errors.inspect
      end
      rval = response.data.to_h.dig(*properties.map {|p| p.to_s})
      unless rval
        # puts "can't find nested field #{properties.join(',')} in query with params:"
        # pp variables
        # puts "response was:"
        # pp response.data.to_h
        raise NestedKeyEmpty, "No response entry for nested keys #{properties.join(',')}"
      end
      rval
    end

    def paginated_query(query, variables, *properties)
      pages = 1
      response = checking_query(query, variables, *properties)
      edges = response["edges"]
      # response["edges"] is edges - we can concatinate them.
      unless edges
        raise "response has no edges - was query wrong?"
      end
      # response["pageInfo"] is metadata
      end_cursor = response["pageInfo"]["endCursor"]
      while end_cursor
        pages += 1
        if pages > MAX_PAGES
          $stderr.puts "bailing after #{pages} pages"
          break
        end
        vars_plus_cursor = variables.dup
        vars_plus_cursor[:cursor] = end_cursor
        response = checking_query(query, vars_plus_cursor, *properties)
        next_edges = response["edges"]
        unless next_edges
          raise "response has no edges - was query wrong?"
        end
        edges = edges + next_edges
        end_cursor = response["pageInfo"]["endCursor"]
      end
      edges
    end

    def filter_teams_list(teams_list)
      result = []
      teams_with_repo_permission = teams_list.select {|node| !node["node"]["repositories"]["edges"].empty?}
      teams_with_repo_permission.each do |team|
        team["node"]["repositories"]["edges"].each do |repo|
          if @reponame == repo["node"]["name"] and "ADMIN" == repo["permission"]
            team_result = Hash["name" => team["node"]["name"], "node_id" => team["node"]["id"]]
            result << team_result
          end
        end
      end
      return result
    end

    def get_team_members(team_list)
      team_members = []
      team_list.each do |team|
        team_members.concat paginated_query(MEMBERS_QUERY, {node_id: team["node_id"]}, :node, :members)
      end
      team_members
    end

    def get_all_owners_from_github()
      paginated_query(REPO_QUERY, {orgname: @orgname, repo: @reponame}, :organization, :repository, :collaborators)
    end

    def get_all_teams_from_github()
      paginated_query(TEAMS_QUERY, {orgname: @orgname, repo: @reponame}, :organization, :teams)
    end

    def get_admin_users()
      begin
        get_all_owners_from_github.select {|collaborator| collaborator['permission'] == 'ADMIN' }
        .map {|collaborator| collaborator['node']}
      rescue NestedKeyEmpty
        puts "Failed with normal approach, attempting to lookup admins via teams..."
        result = get_all_teams_from_github
        admin_teams_list = filter_teams_list(result)
        team_members = get_team_members(admin_teams_list).map {|member| member['node']}
        return team_members.uniq
      end
    end
  end
end

if __FILE__ == $0
# code run if this is called as a script
  unless ARGV.length == 2
    raise "please specify an organization and a repostory name"
  end
  orgname = ARGV[0]
  reponame = ARGV[1]
  admins = GithubRepositories::RepositoryAdmins.new(orgname, reponame)

  puts "Admins for the #{reponame} repository:"
  admin_list = admins.get_admin_users.sort_by{ |elem| elem['login'].downcase }
  admin_list.each do |admin|
    namestr = admin['name'] || "(no name)"
    puts "#{admin['login']} - #{namestr}"
  end

end
