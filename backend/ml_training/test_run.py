import requests
import re
from html.parser import HTMLParser

class TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_row = False
        self.in_cell = False
        self.current_cell = []
        self.current_row = []
        self.data_points = []
        
    def handle_starttag(self, tag, attrs):
        if tag == 'table':
            self.in_table = True
        elif tag == 'tr' and self.in_table:
            self.in_row = True
            self.current_row = []
        elif tag == 'td' and self.in_row:
            self.in_cell = True
            self.current_cell = []
            
    def handle_endtag(self, tag):
        if tag == 'table':
            self.in_table = False
        elif tag == 'tr' and self.in_row:
            self.in_row = False
            if len(self.current_row) >= 3:
                try:
                    x = int(self.current_row[0].strip())
                    char = self.current_row[1].strip()
                    y = int(self.current_row[2].strip())
                    self.data_points.append((x, y, char))
                except (ValueError, IndexError):
                    pass
        elif tag == 'td' and self.in_cell:
            self.in_cell = False
            self.current_row.append(''.join(self.current_cell).strip())
            
    def handle_data(self, data):
        if self.in_cell:
            self.current_cell.append(data)

def decode_secret_message(doc_url):
    response = requests.get(doc_url)
    response.raise_for_status()
    content = response.text
    
    
    parser = TableParser()
    parser.feed(content)
    data_points = parser.data_points
    
    if not data_points:
        raise ValueError("No coordinate data found in the document.")
    
  
    max_x = max(point[0] for point in data_points)
    max_y = max(point[1] for point in data_points)
    
    
    grid = [[' ' for _ in range(max_x + 1)] for _ in range(max_y + 1)]
    

    for x, y, char in data_points:
        inverted_y = max_y - y  
        grid[inverted_y][x] = char
    

    for row in grid:
        print(''.join(row))

decode_secret_message("https://docs.google.com/document/d/e/2PACX-1vSvM5gDlNvt7npYHhp_XfsJvuntUhq184By5xO_pA4b_gCWeXb6dM6ZxwN8rE6S4ghUsCj2VKR21oEP/pub")
# decode_secret_message("https://docs.google.com/document/d/e/2PACX-1vTMOmshQe8YvaRXi6gEPKKlsC6UpFJSMAk4mQjLm_u1gmHdVVTaeh7nBNFBRlui0sTZ-snGwZM4DBCT/pub")