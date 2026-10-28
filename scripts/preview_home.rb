#!/usr/bin/env ruby
# Lightweight local renderer for _pages/about.html.
# It supports only the Liquid tags used by the homepage project cards.

require "cgi"
require "yaml"

ROOT = File.expand_path("..", __dir__)
ABOUT = File.join(ROOT, "_pages", "about.html")
LAYOUT = File.join(ROOT, "_layouts", "tailwind.html")
PAPERS = File.join(ROOT, "_data", "papers.yml")
OUTPUT = File.join(ROOT, "preview.html")

def strip_front_matter(text)
  text.sub(/\A---\n.*?\n---\n/m, "")
end

def paper_value(paper, expression)
  expression = expression.strip

  if expression.include?("| default:")
    primary, fallback = expression.split("| default:", 2).map(&:strip)
    value = paper_value(paper, primary)
    return value.to_s.empty? ? paper_value(paper, fallback) : value
  end

  if expression.include?("| replace:")
    primary, args = expression.split("| replace:", 2).map(&:strip)
    value = paper_value(paper, primary).to_s
    old_value, new_value = args.scan(/'([^']*)'/).flatten
    return value.gsub(old_value.to_s, new_value.to_s)
  end

  if expression.start_with?("paper.")
    return paper[expression.sub("paper.", "")]
  end

  ""
end

def render_paper_vars(template, paper)
  template.gsub(/\{\{\s*(paper\.[^}]*)\s*\}\}/) do
    raw = paper_value(paper, Regexp.last_match(1)).to_s
    # Attribute contexts in this page are simple quoted attributes. Escaping all
    # output is close enough for preview and keeps titles with ampersands valid.
    CGI.escapeHTML(raw)
  end
end

content = strip_front_matter(File.read(ABOUT))
papers = YAML.load_file(PAPERS)

current_project = nil
current_papers = []
output = +""
lines = content.lines
i = 0

while i < lines.length
  line = lines[i]

  if line =~ /\{%\s*assign\s+proj\s*=\s*"([^"]+)"\s*%\}/
    current_project = Regexp.last_match(1)
    i += 1
    next
  end

  if line =~ /\{%\s*assign\s+papers\s*=\s*site\.data\.papers\s*\|\s*where:\s*"project",\s*proj\s*%\}/
    current_papers = papers.select { |paper| paper["project"] == current_project }
    i += 1
    next
  end

  if line =~ /\{%\s*for\s+paper\s+in\s+papers(?:\s+limit:(\d+))?\s*%\}/
    limit = Regexp.last_match(1)&.to_i
    block = +""
    i += 1
    until i >= lines.length || lines[i] =~ /\{%\s*endfor\s*%\}/
      block << lines[i]
      i += 1
    end
    selected_papers = limit ? current_papers.first(limit) : current_papers
    selected_papers.each do |paper|
      output << render_paper_vars(block, paper)
    end
    i += 1
    next
  end

  output << line
  i += 1
end

layout = strip_front_matter(File.read(LAYOUT))
html = layout
  .sub(/<html[^>]*>/, '<html lang="en" class="scroll-smooth">')
  .sub(/\{\%\s*if page\.title.*?\{\%\s*endif\s*\%\}\{\{\s*site\.title\s*\}\}/m, "Hongyang Du | Local Preview")
  .sub(/\{\{\s*page\.excerpt.*?\}\}/m, "Local preview")
  .sub(/\{\{\s*content\s*\}\}/, output)

File.write(OUTPUT, html)
puts "Wrote #{OUTPUT}"
