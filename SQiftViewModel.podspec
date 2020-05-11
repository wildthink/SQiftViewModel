Pod::Spec.new do |s|
  s.name = "SQiftViewModel"
  s.version = "0.9.0"
  s.license = "MIT"
  s.summary = "A lightweight MVVM framework leverging SQLite with SQift."
  s.homepage = "https://github.com/wildthink/SQiftViewModel"
  s.authors = { "Jason Jobe" => "christian.noon@nike.com" }

  s.source = { :git => "https://github.com/wildthink/SQiftViewModel.git", :tag => s.version }
  s.source_files = "Source/**/*.swift"
  s.swift_version = "5.0"

  s.ios.deployment_target = "10.0"
 
  s.dependency 'SQift', git: "https://github.com/wildthink/SQift.git"
end
