FactoryBot.define do
  factory :memory do
    user
    conversation
    summary  { "El usuario preguntó sobre configuración de Rails y resolvimos el problema de rutas." }
    keywords { "rails, rutas, configuración, routes" }
  end
end
