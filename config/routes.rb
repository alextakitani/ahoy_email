Rails.application.routes.draw do
  mount AhoyEmail::Engine => "/ahoy" if AhoyEmail.api
end

AhoyEmail::Engine.routes.draw do
  scope module: "ahoy" do
    get "open" => "messages#open"
    get "click" => "messages#click"

    # legacy
    resources :messages, only: [] do
      get :open, on: :member
      get :click, on: :member
    end
  end
end
