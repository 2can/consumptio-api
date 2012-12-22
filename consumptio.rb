require "cuba"
require "cuba/sugar/as"
require "nokogiri"
require "httparty"
require "json"

module ParseHelper
    def parse_engines(doc)
        engines = []
        doc.css('.aclist_raport .bgl2navy, .aclist_raport tr.bgl1navy').each do |data|
            engines << {
                fuel:    data.css('a.underline').attr('href').value.scan(/-([a-z]*)-/)[0][0] ,
                model:   data.css('a.underline b').text ,
                avg:     data.css('td:nth-child(2) span:first-child').text.sub(',','.') ,
                r_no:    data.css('td:nth-child(3)').text ,
                cost:    data.css('td:last-child span:first-child').text.scan(/[0-9]+,[0-9]*/)[0] ,
                details: data.css('a.underline').attr('href').value
            }
        end

        return engines
    end
end

Cuba.plugin ParseHelper
Cuba.plugin Cuba::Sugar::As

Cuba.define do
    on get do
        on root do
            doc = Nokogiri::HTML(HTTParty.get("http://www.autocentrum.pl/spalanie"))
            collection = []
            doc = doc.css('.m_4lst li a').each do |item|
                 collection << {
                     short: item.attr('href').split('/')[2],
                     name:  item.css('span').text
                 }
            end
            as_json do
                { make: collection }
            end
        end
        on ":make" do |make|
            doc = Nokogiri::HTML(HTTParty.get("http://www.autocentrum.pl/spalanie/#{make}"))
            collection = []
            doc.css('.m_3lst li a').each do |item|
                collection <<  {
                    short: item.attr('href').split('/')[3],
                    name:  item.css('span').text
                }

            end
            models = collection

            on ":model" do |model|
                doc = Nokogiri::HTML(HTTParty.get("http://www.autocentrum.pl/spalanie/#{make}/#{model}"))
                engines = parse_engines(doc)
                generations = false

                if engines.empty?
                    doc.css('ul.gens_list p a').each do |item|
                        engines << {
                            name: item.text,
                            short: item.attr('href').split('/')[4]
                        }
                        generations = true
                    end
                end

                on ":gene" do |gene|
                    doc = Nokogiri::HTML(HTTParty.get("http://www.autocentrum.pl/spalanie/#{make}/#{model}/#{gene}"))
                    engines = parse_engines(doc)
                    as_json do
                        { engines: engines, generations: false }
                    end
                end
                as_json do
                    { engines: engines , generations: generations }
                end
            end
            as_json do
                { model: collection }
            end
        end
    end
end