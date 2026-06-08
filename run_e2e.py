import subprocess
import os
import sys

def run_integration_tests():
    print("🚀 Starting Deltaware End-to-End (Cypress-style) Tests...")
    print("📱 Launching the application in test mode...\n")

    # Ensure the logs directory exists
    os.makedirs("test_reports", exist_ok=True)
    log_file_path = os.path.join("test_reports", "e2e_test_logs.txt")

    # On Windows, 'flutter' is a .bat file so we need shell=True
    command = "flutter test integration_test/app_test.dart"

    try:
        # Run the command and capture output in real-time
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding='utf-8',
            shell=True
        )

        log_content = []
        error_lines = []
        is_error_block = False

        # Read output line by line as the test runs
        with open(log_file_path, "w", encoding='utf-8') as log_file:
            for line in process.stdout:
                log_file.write(line)
                log_content.append(line)
                
                # Print to console so you can watch it live
                sys.stdout.write(line)
                sys.stdout.flush()

                # Simple parsing to catch errors (Flutter test errors often start with "══╡ EXCEPTION" or "Some tests failed")
                if "══╡ EXCEPTION CAUGHT" in line or "Test failed" in line or "Exception:" in line:
                    is_error_block = True
                
                if is_error_block:
                    error_lines.append(line)
                    if line.strip() == "════════════════════════════════════════════════════════════════════════════════════════════════════":
                        is_error_block = False # End of error block

        process.wait()

        print("\n" + "="*60)
        if process.returncode == 0:
            print("✅ ALL TESTS PASSED SUCCESSFULLY!")
        else:
            print("❌ TESTS FAILED. See the summary below:\n")
            print("--- ERROR SUMMARY ---")
            for err in error_lines:
                print(err, end="")
            print("---------------------")
            print(f"\n📄 Full detailed logs have been saved to: {log_file_path}")

    except Exception as e:
        print(f"Failed to run tests: {e}")

if __name__ == "__main__":
    run_integration_tests()
