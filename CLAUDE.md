# Stressless Styling - Project Context

## Project Type
DewWow internal product - managed package for hair salon management.

## Package Details
- **Namespace:** dewwow
- **API Version:** 60.0
- **Development Tool:** CumulusCI

## Key Commands
```bash
# Create scratch org with site
cci flow run dev_org --org dev

# Open scratch org
cci org browser dev

# Deploy changes
cci task run deploy --org dev

# Run tests
cci task run run_tests --org dev
```

## Experience Site
- Name: stressless
- Template: Build Your Own (LWR)
- Authentication: Google SSO (planned)

## Design Reference
Figma: https://www.figma.com/design/MXWlho5ETlbfuwZeBngqRy/stressless-styling

## Development Notes
- All custom objects use dewwow__ namespace prefix in org
- Experience site is created automatically via dev_org flow
