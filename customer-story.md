# Customer Story

![Cloud Coffee Co.](challenges/images/coffee-stock.png)

Cloud Coffee Co. is an independently owned, 'Bean to Bar' coffee company that’s taking the world by storm! They run an organic, fair-trade coffee shop in addition to providing an online ordering platform. Their goal is to provide customers with a highly personalized, omni-channel coffee experience. Their customer-centric mindset also led them to create an incentivized loyalty program that offers exciting rewards to repeat customers.

Through the introduction of the loyalty program and the company’s continued investment in innovative beverage solutions, the loyal base of Cloud Coffee Co. consumers has been growing at an unprecedented pace over the past several months. With the onset of this exciting growth, their current ordering platform has become a bottleneck. The web application is monolithic and was created by a couple of developers when the company was just getting its footing. Based on the company’s rapid progress and the increased demand for its coffee, CCC decided to hire an engineering director to help them create a first-in-class online ordering experience.  

After she evaluated their current application portfolio and IT systems, the company's newly appointed Software Engineering Director recommended rearchitecting and replatforming the solution in order to keep pace with the change the business has- and will continue to- experience. Her recommendation was an event-driven, microservices based architecture for the ordering solution which will enable scalability while mitigating technical debt.

You are part of the Development Team at Cloud Coffee Co. and were able to reuse a bulk of the business logic from the existing ordering application during the refactoring phase of this modernization initiative. The work left to be done involves bringing the various microservices together and deploying them onto a scalable platform.

After evaluating a variety of approaches and technologies, your team has decided to use Dapr, the Distributed Application Runtime, to enable system functionality such as reliable state, publish-subscribe mechanisms, a common secret store and service-to-service invocation. Your solution will include several dapr-enabled microservices and a variety of Azure resources. Your job moving forward is to integrate the microservices together and ensure reliable communication is in place.

Navigate to the [Core Services Overview](./challenges/) to read about each of the services and view the desired final architecture.
