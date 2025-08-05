# PersonalFinance

This application is a personal finance management tool, designed to help users organize their budgets, track transactions, and categorize spending. It provides real-time interactive features powered by Phoenix LiveView, ensuring a responsive user experience.

Built with Elixir and Phoenix, the project leverages Ecto for data persistence and emphasizes a clear separation of concerns through LiveViews and LiveComponents for its frontend architecture.

# TODOs

- [x] Refactor color palette and theme.
- [x] Enchance all form validations and error handling.
- [x] Implement user confirmation modals for all destructive actions.
- [x] Develop profiles settings for managing income and fixed expenses.
- [x] Configure recurring transactions on profile settings.
- [x] Implement recurring transactions from profile settings.
- [x] Implement balances calculation.
- [ ] Design and implement a dashboard with financial charts and summaries.
    - [x] Live update on dashboard (balances, charts, lists)
    - [x] Categories charts
    - [x] Show most recent transactions
    - [x] Show alert messages based on value spent on each category
    - [x] Customize categories colors
    - [x] Responsive dashboard
- [x] Mobile responsiveness improvements.
- [ ] Add advanced search, filter, sort, and pagination features for transactions.
    - [x] Filter
- [x] Change user registration logic
- [x] Change invites logic
- [ ] Add comprehensive test suite (unit, integration, LiveView tests).
- [ ] Implement transaction import and export functionalities (CSV, JSON).
- [ ] Integrate with external APIs to fetch real-time financial data (stocks, cryptocurrencies).
- [ ] Implement investment yield calculation.
- [ ] Add dividend reinvestment tracking.
- [ ] Define and enforce user roles and permissions for shared budgets.
- [ ] Portfolio tracking
    - [ ] Track individual assets and their performanc (stocks, cryptocurrencies, fixed income).
    - [ ] Add personal notes and tags to assets.
    - [ ] Implement a review/analysis feature for assets.
