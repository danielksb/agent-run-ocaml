# TODO: Configure Tool Registry for Testing

## Objective
During testing, the tool registry should be configured to only include the weather tool to ensure focused testing and avoid interference from other tools.

## Steps to Configure the Tool Registry:
1. **Isolation of Tool Registry**  
   - Ensure testing occurs in a separate environment to avoid conflicts with production tools.

2. **Load Only Weather Tool**  
   - Modify the tool registry configuration to include only the following tool:
     - `get_weather`

3. **Remove Other Tools**  
   - Ensure the registry does not load any other tools by commenting out or removing their registration in the test configuration file.

4. **Testing Tools Availability**  
   - Write test cases to verify that only the `get_weather` tool is available and functioning as expected.

5. **Documentation**  
   - Document the changes made in the configuration for future reference and ensure it's clear to all team members.

6. **Review and Cleanup**  
   - After testing is completed, revert any changes to the tool registry to restore all tools for normal operation.

## Conclusion
Following this plan will help ensure that the tool registry during testing is optimized for focused and effective testing of the weather tool.