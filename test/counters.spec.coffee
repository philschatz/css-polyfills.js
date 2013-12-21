define ['cs!./simple'], (simple) ->

  describe 'Counters', () ->

    describe 'counter-reset', () ->
      it 'resets a single counter with no specific value', () ->
        css = '''
          .figure { counter-reset: counter-a; }
          .output { content: counter(counter-a); }
        '''
        html = '''
          <div class="figure"></div>
          <div class="output"></div>
        '''
        expected = '''
          0
        '''
        simple(css, html, expected)

      it 'resets a single counter with a specific value', () ->
        css = '''
          .figure { counter-reset: counter-a -1; }
          .output { content: counter(counter-a); }
        '''
        html = '''
          <div class="figure"></div>
          <div class="output"></div>
        '''
        expected = '''
          -1
        '''
        simple(css, html, expected)

      it 'resets multiple counters', () ->
        css = '''
          .figure { counter-reset: counter-a -1 counter-b; }
          .output-a { content: counter(counter-a); }
          .output-b { content: counter(counter-b); }
        '''
        html = '''
          <div class="figure"></div>
          <div class="output-a"></div>
          <div class="output-b"></div>
        '''
        expected = '''
          -10
        '''
        simple(css, html, expected)

    describe 'counter-increment', () ->
      it 'increments by 1 by default', () ->
        css = '''
          .figure { counter-increment: counter-a; }
          .output { content: counter(counter-a); }
        '''
        html = '''
          <div class="figure"></div>
          <div class="output"></div>
          <div class="figure"></div>
          <div class="output"></div>
        '''
        expected = '''
          1
          2
        '''
        simple(css, html, expected)

      it 'increments by a negative number', () ->
        css = '''
          .figure { counter-increment: counter-a -2; }
          .output { content: counter(counter-a); }
        '''
        html = '''
          <div class="figure"></div>
          <div class="output"></div>
          <div class="figure"></div>
          <div class="output"></div>
        '''
        expected = '''
          -2
          -4
        '''
        simple(css, html, expected)

      it 'increments multiple counters', () ->
        css = '''
          .figure { counter-increment: counter-a -2 counter-b counter-c; }
          .output { content: '[' counter(counter-a) ':' counter(counter-b) ':' counter(counter-c) ']'; }
        '''
        html = '''
          <div class="figure"></div>
          <div class="output"></div>
          <div class="figure"></div>
          <div class="output"></div>
        '''
        expected = '''
          [-2:1:1]
          [-4:2:2]
        '''
        simple(css, html, expected)

    describe 'content: counter(...)', () ->
      it 'supports uninitialized counters', () ->
        css = '''
          .test { content: '[' counter(counter-uninitialized) ']'; }
        '''
        html = '''
          <div class="test"></div>
        '''
        expected = '''
          [0]
        '''
        simple(css, html, expected)

      it 'supports decimal-leading-zero', () ->
        css = '''
          .test {
            counter-increment: counter-a 2;
            content: '[' counter(counter-a, decimal-leading-zero) ']';
          }
        '''
        html = '''
          <div class="test"></div>
          <div class="test"></div>
          <div class="test"></div>
          <div class="test"></div>
          <div class="test"></div>
          <div class="test"></div>
          <div class="test"></div>
        '''
        expected = '''
          [02] [04] [06] [08] [10] [12] [14]
        '''
        simple(css, html, expected)

      it 'supports lower-roman', () ->
        css = '''
          div { content: '[' counter(counter-a, lower-roman) ']'; }
          div { counter-reset: counter-a attr(data-count); }
        '''
        html = '''
          <div data-count="0"></div>
          <div data-count="1"></div>
          <div data-count="2"></div>
          <div data-count="4"></div>
          <div data-count="5"></div>
          <div data-count="6"></div>
          <div data-count="9"></div>
          <div data-count="10"></div>
          <div data-count="11"></div>
          <div data-count="39"></div>
          <div data-count="40"></div>
          <div data-count="41"></div>
          <div data-count="49"></div>
          <div data-count="50"></div>
          <div data-count="51"></div>
          <div data-count="89"></div>
          <div data-count="90"></div>
          <div data-count="91"></div>
          <div data-count="99"></div>
          <div data-count="100"></div>
          <div data-count="101"></div>
          <div data-count="399"></div>
          <div data-count="400"></div>
          <div data-count="401"></div>
          <div data-count="499"></div>
          <div data-count="500"></div>
          <div data-count="501"></div>
          <div data-count="899"></div>
          <div data-count="900"></div>
          <div data-count="901"></div>
          <div data-count="999"></div>
          <div data-count="1000"></div>
          <div data-count="1001"></div>
          <div data-count="4998"></div>
          <div data-count="4999"></div>
          <div data-count="5000"></div>
        '''
        expected = '''
          [0]
          [i][ii][iv][v][vi][ix][x][xi][xxxix][xl][xli][xlix][l][li][lxxxix]
          [xc][xci][xcix][c][ci][cccxcix][cd][cdi][cdxcix][d][di][dcccxcix]
          [cm][cmi][cmxcix][m][mi][mmmmcmxcviii][mmmmcmxcix]
          [5000]
        '''
        simple(css, html, expected)

      it 'supports upper-roman', () ->
        css = '''
          div { content: '[' counter(counter-a, upper-roman) ']'; }
          div { counter-reset: counter-a attr(data-count); }
        '''
        html = '''
          <div data-count="0"></div>
          <div data-count="1"></div>
          <div data-count="4"></div>
          <div data-count="5"></div>
          <div data-count="9"></div>
          <div data-count="10"></div>
          <div data-count="40"></div>
          <div data-count="50"></div>
          <div data-count="90"></div>
          <div data-count="100"></div>
          <div data-count="400"></div>
          <div data-count="500"></div>
          <div data-count="900"></div>
          <div data-count="1000"></div>
          <div data-count="4999"></div>
          <div data-count="5000"></div>
        '''
        expected = '''
          [0]
          [I][IV][V][IX][X][XL][L][XC][C][CD][D][CM][M][MMMMCMXCIX]
          [5000]
        '''
        simple(css, html, expected)

      it 'supports lower-latin', () ->
        css = '''
          div { content: '[' counter(counter-a, lower-latin) ']'; }
          div { counter-reset: counter-a attr(data-count); }
        '''
        html = '''
          <div data-count="0"></div>
          <div data-count="1"></div>
          <div data-count="2"></div>
          <div data-count="25"></div>
          <div data-count="26"></div>
          <div data-count="27"></div>
        '''
        expected = '''
          [0]
          [a][b][y][z]
          [27]
        '''
        simple(css, html, expected)

      it 'supports upper-latin', () ->
        css = '''
          div { content: '[' counter(counter-a, upper-latin) ']'; }
          div { counter-reset: counter-a attr(data-count); }
        '''
        html = '''
          <div data-count="0"></div>
          <div data-count="1"></div>
          <div data-count="2"></div>
          <div data-count="25"></div>
          <div data-count="26"></div>
          <div data-count="27"></div>
        '''
        expected = '''
          [0]
          [A][B][Y][Z]
          [27]
        '''
        simple(css, html, expected)


  describe 'target-* functions', () ->

    it 'does not care if the target-counter occurs before, above, after, or below', () ->
      css = '''
        .chap { counter-increment: chap foo; }
        .chap:before { content: 'Ch ' counter(chap) ': '; }

        .xref {
          content: 'See ' target-counter(attr(href), chap);
        }
      '''
      html = '''
        - <a href="#id1" class="xref">Link</a>
        - <a href="#id2" class="xref">Link</a>
        - <a href="#id3" class="xref">Link</a>
        - <a href="#id4" class="xref">Link</a>


        <div id="id1" class="chap">
          <div id="id2" class="chap">
            - <a href="#id1" class="xref">Link</a>
            - <a href="#id2" class="xref">Link</a>
            - <a href="#id3" class="xref">Link</a>
            - <a href="#id4" class="xref">Link</a>
          </div>
        </div>


        <div id="id3" class="chap">
          <div id="id4" class="chap">
            - <a href="#id1" class="xref">Link</a>
            - <a href="#id2" class="xref">Link</a>
            - <a href="#id3" class="xref">Link</a>
            - <a href="#id4" class="xref">Link</a>
          </div>
        </div>

        - <a href="#id1" class="xref">Link</a>
        - <a href="#id2" class="xref">Link</a>
        - <a href="#id3" class="xref">Link</a>
        - <a href="#id4" class="xref">Link</a>
      '''
      expected = '''
        - See 1 - See 2 - See 3 - See 4
        Ch 1:
        Ch 2: - See 1 - See 2 - See 3 - See 4
        Ch 3:
        Ch 4: - See 1 - See 2 - See 3 - See 4
        - See 1 - See 2 - See 3 - See 4
      '''
      simple(css, html, expected)

    it 'supports the x-target-is(id, "> .selector") guard function', () ->
      css = '''
        a[href] {
          // content: '[LINK]';
          content: x-target-is(attr(href), 'table')           '[TABLE]';
          content: x-target-is(attr(href), 'figure')          '[FIGURE]';
          content: x-target-is(attr(href), 'figure > figure') '[SUBFIGURE]';
        }
      '''
      html = '''
        <div id="id-nothing"></div>
        <a href="#id-nothing">IGNORE</a>
        <table id="id-table"></table>
        <a href="#id-table">FAIL</a>
        <figure id="id-figure"></figure>
        <a href="#id-figure">FAIL</a>
        <figure id="id-figure2"><figure id="id-subfigure"></figure></figure>
        <a href="#id-subfigure">FAIL</a>
        <a href="#id-figure2">FAIL</a>
      '''
      expected = '''
        IGNORE
        [TABLE]
        [FIGURE]
        [SUBFIGURE]
        [FIGURE]
      '''
      simple(css, html, expected)
