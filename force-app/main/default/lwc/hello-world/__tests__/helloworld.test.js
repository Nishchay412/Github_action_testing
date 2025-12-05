import { createElement } from 'lwc';
import HelloWorld from 'c/helloWorld';

describe('c-hello-world', () => {
  afterEach(() => {
    // Clean up DOM between tests
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it('renders default greeting', () => {
    const element = createElement('c-hello-world', {
      is: HelloWorld
    });
    document.body.appendChild(element);

    const p = element.shadowRoot.querySelector('p');
    expect(p.textContent).toBe('Hello, World!');
  });

  it('renders custom name when @api name is set', () => {
    const element = createElement('c-hello-world', {
      is: HelloWorld
    });
    element.name = 'Legend';
    document.body.appendChild(element);

    return Promise.resolve().then(() => {
      const p = element.shadowRoot.querySelector('p');
      expect(p.textContent).toBe('Hello, Legend!');
    });
  });
});
