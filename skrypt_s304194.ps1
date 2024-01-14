# Changelog:
# Utworzony dnia: 27-12-2023
# Opis: Skrypt do pobrania, walidacji danych oraz załadowania ich do bazy danych.
# Dodatkowe informacje: użyto bazy danych Microsoft SQL Server oraz narzedzia WinRAR do rozpakowania danych

# Definicje zmiennych
$downloadUrl = "http://home.agh.edu.pl/~wsarlej/dyd/bdp2/materialy/cw10/InternetSales_new.zip"


$path = Read-Host -Prompt 'Wprowadź ścieżkę do folderu'
$downloadPath = $path 
$unzipPath = $path 
$processedPath = "$path\PROCESSED"
$badFilePath = "$path\InternetSales_new.bad_$(Get-Date -Format 'yyyyMMddHHmmss')"
$zipPassword = Read-Host -Prompt 'Wprowadź hasło do zip'
$indexNumber = "304194"
$winrarPath = "C:\Program Files\WinRAR\WinRAR.exe" #nalezy podac lokalizcje pliku WinRAR.exe

# Definicje zmiennych bazy danych 
# Authentication method - Windows Authentication
$databaseServer = "LAPTOP-J7F0DSF0"
$databaseName = "zad10"
$tableName = "CUSTOMERS_$indexNumber"

# Pobranie nazwy bieżącego skryptu
$scriptName = $MyInvocation.MyCommand.Name
$logPath = "$processedPath\$scriptName_$(Get-Date -Format 'yyyyMMddHHmmss').log"

# Tworzenie folderu PROCESSED
if(!(Test-Path -Path $processedPath ))
{
    New-Item -ItemType directory -Path $processedPath
}

# Funkcja do logowania
function Log-Message {
    param (
        [Parameter(Mandatory=$true)]
        [string] $Message
    )

    # Pobranie aktualnej daty i czasu
    $timestamp = Get-Date -Format 'MM/dd/yyyy hh:mm:ss'

    # Dodanie wiadomości do pliku logów
    Add-Content -Path $logPath -Value "$timestamp – $Message - Successful"

    # Wyświetlenie wiadomości w konsoli
    Write-Host "$timestamp – $Message - Completed"
}

# Pobieranie pliku
Invoke-WebRequest -Uri $downloadUrl -OutFile "$downloadPath\InternetSales_new.zip"
Log-Message -Message "Download Step"

# Rozpakowywanie pliku
& $winrarPath x -ibck -inul -p"$zipPassword" "$downloadPath\InternetSales_new.zip" "$unzipPath\"
Log-Message -Message "Unzip Step"

Start-Sleep -Seconds 2  # Odczekaj 2 sekund

# Odczytanie pliku CSV
$csv = Import-Csv -Path "$unzipPath\InternetSales_new.txt" -Delimiter '|'

# Pobranie nagłówka (nazw kolumn)
$header = $csv[0].PSObject.Properties.Name

# Inicjalizacja pustej tablicy na poprawne wiersze
$validRows = @()

# Inicjalizacja pustej tablicy na błędne wiersze
$badRows = @()

# Usunięcie duplikatów
$csv = $csv | Sort-Object * -Unique

foreach ($row in $csv) {
    # Sprawdzenie, czy wiersz ma tyle samo kolumn co nagłówek
    if ($row.PSObject.Properties.Name.Count -eq $header.Count) {
        # Sprawdzenie, czy OrderQuantity jest mniejsze lub równe 100
        if ([int]$row.OrderQuantity -le 100) {
            # Sprawdzenie, czy SecretCode jest pusty
            if ([string]::IsNullOrEmpty($row.SecretCode)) {
                # Sprawdzenie, czy Customer_Name jest w formacie "nazwisko,imie"
                if ($row.Customer_Name -match '^[^,]+,[^,]+$') {
                    # Podział Customer_Name na FIRST_NAME i LAST_NAME
                    $firstName, $lastName = $row.Customer_Name.Split(',')

                    # Dodanie nowych kolumn do wiersza
                    $row | Add-Member -NotePropertyName 'FIRST_NAME' -NotePropertyValue $firstName.Trim()
                    $row | Add-Member -NotePropertyName 'LAST_NAME' -NotePropertyValue $lastName.Trim()

                    # Usunięcie kolumny Customer_Name
                    $row.PSObject.Properties.Remove('Customer_Name')


                    # Dodanie wiersza do tablicy poprawnych wierszy
                    $validRows += $row
                } else {
                    # Dodanie wiersza do tablicy błędnych wierszy
                    $badRows += $row
                }
            } else {
                # Dodanie wiersza do tablicy błędnych wierszy
                $badRows += $row
            }
        } else {
            # Dodanie wiersza do tablicy błędnych wierszy
            $badRows += $row
        }
    } else {
        # Dodanie wiersza do tablicy błędnych wierszy
        $badRows += $row
    }
}

# Zapisanie poprawnych wierszy do pliku CSV
$validRows | Export-Csv -Path "$unzipPath\InternetSales_new.csv" -NoTypeInformation

# Zapisanie błędnych wierszy do pliku .bad
$badRows | Export-Csv -Path $badFilePath -NoTypeInformation
Log-Message -Message "Validation Step"

# Połączenie z bazą danych
$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = "Server=$databaseServer;Database=$databaseName;Integrated Security=True;"

# Zapytanie SQL
$query = @"
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = '$tableName')
BEGIN
    DROP TABLE $tableName
END

CREATE TABLE $tableName (
    ProductKey INT,
    CurrencyAlternateKey VARCHAR(255),
    FIRST_NAME VARCHAR(255),
    LAST_NAME VARCHAR(255),
    OrderDateKey DATE,
    OrderQuantity VARCHAR(255),
    UnitPrice VARCHAR(255),
    SecretCode VARCHAR(255)
)
"@

# Wykonanie zapytania SQL
$command = $conn.CreateCommand() 
$command.CommandText = $query

$conn.Open()
$command.ExecuteNonQuery() > $null
Log-Message -Message "Table Creation Step"

# Odczytanie pliku CSV
$csvData = Import-Csv -Path $unzipPath\InternetSales_new.csv

foreach ($row in $csvData) {
    # Zapytanie SQL do wstawienia danych
    $query = @"
    INSERT INTO $tableName (ProductKey, CurrencyAlternateKey, OrderDateKey, OrderQuantity, UnitPrice, SecretCode, FIRST_NAME, LAST_NAME)
    VALUES ('$($row.ProductKey)', '$($row.CurrencyAlternateKey)', '$($row.OrderDateKey)', '$($row.OrderQuantity)', '$($row.UnitPrice)', '$($row.SecretCode)', '$($row.FIRST_NAME)', '$($row.LAST_NAME)')
"@

    # Wykonanie zapytania SQL
    $command = $conn.CreateCommand()
    $command.CommandText = $query 
    $command.ExecuteNonQuery() > $null
}
Log-Message -Message "Data Insertion Step"

# Przenoszenie przetworzonego pliku
Move-Item -Path "$unzipPath\InternetSales_new.csv" -Destination "$processedPath\$(Get-Date -Format 'yyyyMMddHHmmss')_InternetSales_new_processed.csv"
Log-Message -Message "File Move Step"

# Zapytanie SQL do aktualizacji danych
#NEWID() generuje unikalny identyfikator GUID 5 pierwszych i ostatnich jego znaków
$query = @"
UPDATE $tableName
SET SecretCode = LEFT(NEWID(), 5) + RIGHT(NEWID(), 5)
"@

# Wykonanie zapytania SQL
$command = $conn.CreateCommand()
$command.CommandText = $query
$command.ExecuteNonQuery() > $null
Log-Message -Message "Data Update Step"

# Zapytanie SQL do wyboru wszystkich danych z tabeli
$query = "SELECT * FROM $tableName"

# Wykonanie zapytania SQL
$command = $conn.CreateCommand()
$command.CommandText = $query
$reader = $command.ExecuteReader()

# Eksportowanie danych do pliku CSV
$table = new-object 'System.Data.DataTable'
$table.Load($reader)
$table | Export-Csv -Path "$processedPath\Exported_Customers.csv" -NoTypeInformation -Encoding UTF8 -Delimiter "`t"
Log-Message -Message "Data Export Step"

# Zamknięcie połączenia z bazą danych
$conn.Close()


# Kompresowanie pliku csv
Compress-Archive -Path "$processedPath\Exported_Customers.csv" -DestinationPath "$processedPath\Exported_Customers.zip"
Log-Message -Message "File Compression Step"